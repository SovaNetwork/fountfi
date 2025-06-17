// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {tRWA} from "./tRWA.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IDirectDepositStrategy} from "../strategy/IDirectDepositStrategy.sol";
import {IHook} from "../hooks/IHook.sol";

/**
 * @title DirectDepositRWA
 * @notice tRWA variant where deposits go directly to issuer wallet with pending deposit tracking
 * @dev Tracks pending deposits and allows issuer to mint shares against specific deposits
 */
contract DirectDepositRWA is tRWA {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    error OnlyIssuer();
    error InvalidRecipient();
    error InvalidAmount();
    error InvalidArrayLengths();
    error DepositNotFound();
    error DepositNotPending();
    error InvalidExpirationPeriod();
    error Unauthorized();

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event DirectDeposit(address indexed from, address indexed issuerWallet, uint256 assets);
    event DepositPending(
        bytes32 indexed depositId, address indexed depositor, address indexed recipient, uint256 assets
    );
    event DepositAccepted(bytes32 indexed depositId, address indexed recipient, uint256 assets, uint256 shares);
    event DepositRefunded(bytes32 indexed depositId, address indexed depositor, uint256 assets);
    event DepositReclaimed(bytes32 indexed depositId, address indexed depositor, uint256 assets);
    event BatchDepositsAccepted(bytes32[] depositIds, uint256 totalAssets, uint256 totalShares);
    event DepositExpirationPeriodUpdated(uint256 oldPeriod, uint256 newPeriod);

    /*//////////////////////////////////////////////////////////////
                            STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Enum to track the deposit state
    enum DepositState {
        PENDING,
        ACCEPTED,
        REFUNDED
    }

    /// @notice Struct to track pending deposit information
    struct PendingDeposit {
        address depositor; // Address that initiated the deposit
        address recipient; // Address that will receive shares if approved
        uint256 assetAmount; // Amount of assets deposited
        uint256 expirationTime; // Timestamp after which deposit can be reclaimed
        DepositState state; // Current state of the deposit
    }

    /// @notice Storage for deposits
    mapping(bytes32 => PendingDeposit) public pendingDeposits;

    /// @notice Deposit tracking
    bytes32[] public depositIds;

    /// @notice Mapping of user addresses to their deposit IDs
    mapping(address => bytes32[]) public userDepositIds;

    /// @notice Monotonically-increasing sequence number to guarantee unique depositIds
    uint256 private sequenceNum;

    /// @notice Deposit expiration time (in seconds) - default to 7 days
    uint256 public depositExpirationPeriod = 7 days;

    /// @notice Maximum deposit expiration period
    uint256 public constant MAX_DEPOSIT_EXPIRATION_PERIOD = 30 days;

    /// @notice Accounting for total pending assets
    uint256 public totalPendingAssets;

    /// @notice Accounting for user pending assets
    mapping(address => uint256) public userPendingAssets;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(string memory name_, string memory symbol_, address asset_, uint8 assetDecimals_, address strategy_)
        tRWA(name_, symbol_, asset_, assetDecimals_, strategy_)
    {}

    /*//////////////////////////////////////////////////////////////
                        CONFIGURATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the period after which deposits expire and can be reclaimed
     * @param newExpirationPeriod New expiration period in seconds
     */
    function setDepositExpirationPeriod(uint256 newExpirationPeriod) external onlyStrategy {
        if (newExpirationPeriod == 0) revert InvalidExpirationPeriod();
        if (newExpirationPeriod > MAX_DEPOSIT_EXPIRATION_PERIOD) revert InvalidExpirationPeriod();

        uint256 oldPeriod = depositExpirationPeriod;
        depositExpirationPeriod = newExpirationPeriod;

        emit DepositExpirationPeriodUpdated(oldPeriod, newExpirationPeriod);
    }

    /*//////////////////////////////////////////////////////////////
                    ERC4626 OVERRIDE DEPOSIT FUNCTION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Override deposit to send assets to issuer wallet and track pending deposits
     * @dev Creates a pending deposit record that issuer must accept to mint shares
     * @param by Address of the sender
     * @param to Address that will receive shares when issuer accepts
     * @param assets Amount of assets to deposit
     * @param shares Amount of shares that would be minted (used for event)
     */
    function _deposit(address by, address to, uint256 assets, uint256 shares) internal virtual override nonReentrant {
        // Run deposit hooks
        HookInfo[] storage opHooks = operationHooks[OP_DEPOSIT];
        for (uint256 i = 0; i < opHooks.length;) {
            IHook.HookOutput memory hookOutput = opHooks[i].hook.onBeforeDeposit(address(this), by, assets, to);
            if (!hookOutput.approved) {
                revert HookCheckFailed(hookOutput.reason);
            }
            opHooks[i].hasProcessedOperations = true;
            unchecked {
                ++i;
            }
        }

        // Get issuer wallet from strategy
        address issuerWallet = IDirectDepositStrategy(strategy).issuerWallet();

        // Generate a unique deposit ID
        bytes32 depositId = keccak256(abi.encodePacked(by, to, assets, block.timestamp, address(this), sequenceNum++));

        // Record the deposit
        pendingDeposits[depositId] = PendingDeposit({
            depositor: by,
            recipient: to,
            assetAmount: assets,
            expirationTime: block.timestamp + depositExpirationPeriod,
            state: DepositState.PENDING
        });

        // Track deposit ID
        depositIds.push(depositId);
        userDepositIds[by].push(depositId);

        // Update accounting
        totalPendingAssets += assets;
        userPendingAssets[by] += assets;

        // Transfer assets directly to issuer wallet
        SafeTransferLib.safeTransferFrom(asset(), by, issuerWallet, assets);

        emit DirectDeposit(by, issuerWallet, assets);
        emit DepositPending(depositId, by, to, assets);
        emit Deposit(by, to, assets, shares);
    }

    /*//////////////////////////////////////////////////////////////
                    DEPOSIT ACCEPTANCE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Accept a pending deposit and mint shares
     * @param depositId The deposit ID to accept
     */
    function acceptDeposit(bytes32 depositId) external onlyStrategy {
        PendingDeposit storage deposit = pendingDeposits[depositId];
        if (deposit.depositor == address(0)) revert DepositNotFound();
        if (deposit.state != DepositState.PENDING) revert DepositNotPending();

        // Mark as accepted
        deposit.state = DepositState.ACCEPTED;

        // Update accounting
        totalPendingAssets -= deposit.assetAmount;
        userPendingAssets[deposit.depositor] -= deposit.assetAmount;

        // Calculate shares based on current exchange rate
        uint256 shares = previewDeposit(deposit.assetAmount);

        // Mint shares to the recipient
        _mint(deposit.recipient, shares);

        emit DepositAccepted(depositId, deposit.recipient, deposit.assetAmount, shares);
    }

    /**
     * @notice Accept multiple pending deposits as a batch
     * @param ids Array of deposit IDs to accept
     */
    function batchAcceptDeposits(bytes32[] calldata ids) external onlyStrategy {
        if (ids.length == 0) return;

        uint256 totalAssets = 0;
        uint256 totalShares = 0;

        for (uint256 i = 0; i < ids.length;) {
            bytes32 depositId = ids[i];
            PendingDeposit storage deposit = pendingDeposits[depositId];

            // Validate deposit
            if (deposit.depositor == address(0)) revert DepositNotFound();
            if (deposit.state != DepositState.PENDING) revert DepositNotPending();

            // Mark as accepted
            deposit.state = DepositState.ACCEPTED;

            // Update accounting
            userPendingAssets[deposit.depositor] -= deposit.assetAmount;

            // Calculate shares for this deposit
            uint256 shares = previewDeposit(deposit.assetAmount);

            // Mint shares to the recipient
            _mint(deposit.recipient, shares);

            // Accumulate totals
            totalAssets += deposit.assetAmount;
            totalShares += shares;

            emit DepositAccepted(depositId, deposit.recipient, deposit.assetAmount, shares);

            unchecked {
                ++i;
            }
        }

        totalPendingAssets -= totalAssets;

        emit BatchDepositsAccepted(ids, totalAssets, totalShares);
    }

    /**
     * @notice Refund a pending deposit
     * @dev Issuer must transfer assets back from issuer wallet before calling
     * @param depositId The deposit ID to refund
     */
    function refundDeposit(bytes32 depositId) external onlyStrategy {
        PendingDeposit storage deposit = pendingDeposits[depositId];
        if (deposit.depositor == address(0)) revert DepositNotFound();
        if (deposit.state != DepositState.PENDING) revert DepositNotPending();

        // Mark as refunded
        deposit.state = DepositState.REFUNDED;

        // Update accounting
        totalPendingAssets -= deposit.assetAmount;
        userPendingAssets[deposit.depositor] -= deposit.assetAmount;

        // Transfer assets from this contract to depositor
        // Note: Strategy must ensure funds are available before calling
        SafeTransferLib.safeTransfer(asset(), deposit.depositor, deposit.assetAmount);

        emit DepositRefunded(depositId, deposit.depositor, deposit.assetAmount);
    }

    /**
     * @notice Allow a user to reclaim their expired deposit
     * @dev User can only reclaim if deposit has expired
     * @param depositId The deposit ID to reclaim
     */
    function reclaimDeposit(bytes32 depositId) external {
        PendingDeposit storage deposit = pendingDeposits[depositId];
        if (deposit.depositor == address(0)) revert DepositNotFound();
        if (deposit.state != DepositState.PENDING) revert DepositNotPending();
        if (msg.sender != deposit.depositor) revert Unauthorized();
        if (block.timestamp < deposit.expirationTime) revert Unauthorized();

        // Mark as refunded
        deposit.state = DepositState.REFUNDED;

        // Update accounting
        totalPendingAssets -= deposit.assetAmount;
        userPendingAssets[deposit.depositor] -= deposit.assetAmount;

        // Transfer assets from strategy (it must have funds available)
        SafeTransferLib.safeTransferFrom(asset(), strategy, deposit.depositor, deposit.assetAmount);

        emit DepositReclaimed(depositId, deposit.depositor, deposit.assetAmount);
    }

    /*//////////////////////////////////////////////////////////////
                        LEGACY MINTING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Legacy function for direct minting (kept for compatibility)
     * @dev Can only be called by the issuer through the strategy
     * @param recipient Address to receive the shares
     * @param shares Amount of shares to mint
     */
    function mintShares(address recipient, uint256 shares) external onlyStrategy {
        if (recipient == address(0)) revert InvalidRecipient();
        if (shares == 0) revert InvalidAmount();

        _mint(recipient, shares);
    }

    /**
     * @notice Legacy batch mint function (kept for compatibility)
     * @dev Can only be called by the issuer through the strategy
     * @param recipients Array of recipient addresses
     * @param shares Array of share amounts aligned with recipients
     */
    function batchMintShares(address[] calldata recipients, uint256[] calldata shares) external onlyStrategy {
        // Validate array lengths match
        if (recipients.length != shares.length) {
            revert InvalidArrayLengths();
        }

        // Track total shares minted for event
        uint256 totalShares = 0;

        // Mint shares to each recipient
        for (uint256 i = 0; i < recipients.length;) {
            if (recipients[i] == address(0)) revert InvalidRecipient();
            if (shares[i] == 0) revert InvalidAmount();

            _mint(recipients[i], shares[i]);
            totalShares += shares[i];

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get all pending deposit IDs for a specific user
     * @param user The user address
     * @return Array of deposit IDs that are still pending
     */
    function getUserPendingDeposits(address user) external view returns (bytes32[] memory) {
        bytes32[] memory userDeposits = new bytes32[](userDepositIds[user].length);
        uint256 count = 0;

        for (uint256 i = 0; i < userDepositIds[user].length;) {
            bytes32 depositId = userDepositIds[user][i];
            PendingDeposit memory deposit = pendingDeposits[depositId];

            // Only include if state is PENDING
            if (deposit.state == DepositState.PENDING) {
                userDeposits[count] = depositId;
                count++;
            }

            unchecked {
                ++i;
            }
        }

        // Resize array to fit only pending deposits
        bytes32[] memory result = new bytes32[](count);
        for (uint256 i = 0; i < count;) {
            result[i] = userDeposits[i];

            unchecked {
                ++i;
            }
        }

        return result;
    }

    /**
     * @notice Get details for a specific deposit
     * @param depositId The unique identifier of the deposit
     * @return depositor The address that initiated the deposit
     * @return recipient The address that will receive shares if approved
     * @return assetAmount The amount of assets deposited
     * @return expirationTime The timestamp after which deposit can be reclaimed
     * @return state The current state of the deposit (0=PENDING, 1=ACCEPTED, 2=REFUNDED)
     */
    function getDepositDetails(bytes32 depositId)
        external
        view
        returns (address depositor, address recipient, uint256 assetAmount, uint256 expirationTime, uint8 state)
    {
        PendingDeposit memory deposit = pendingDeposits[depositId];
        return (deposit.depositor, deposit.recipient, deposit.assetAmount, deposit.expirationTime, uint8(deposit.state));
    }
}
