// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {tRWA} from "./tRWA.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IDirectDepositStrategy} from "../strategy/IDirectDepositStrategy.sol";
import {IHook} from "../hooks/IHook.sol";

/**
 * @title DirectDepositRWA
 * @notice tRWA variant where deposits go directly to issuer wallet instead of strategy
 * @dev Overrides deposit functionality to send assets to issuer-controlled wallet
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

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event DirectDeposit(address indexed from, address indexed issuerWallet, uint256 assets);
    event IssuerMint(address indexed recipient, uint256 shares, address indexed issuer);
    event BatchSharesMinted(address[] recipients, uint256[] shares, uint256 totalShares);

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(string memory name_, string memory symbol_, address asset_, uint8 assetDecimals_, address strategy_)
        tRWA(name_, symbol_, asset_, assetDecimals_, strategy_)
    {}

    /*//////////////////////////////////////////////////////////////
                    ERC4626 OVERRIDE DEPOSIT FUNCTION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Override deposit to send assets directly to issuer wallet
     * @dev Does not automatically mint shares - issuer must call mintShares
     * @param by Address of the sender
     * @param to Address that will receive shares (stored for when issuer mints)
     * @param assets Amount of assets to deposit
     * @param shares Amount of shares that would be minted (ignored in this implementation)
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

        // Transfer assets directly to issuer wallet instead of strategy
        SafeTransferLib.safeTransferFrom(asset(), by, issuerWallet, assets);

        emit DirectDeposit(by, issuerWallet, assets);
        emit Deposit(by, to, assets, shares);
    }

    /*//////////////////////////////////////////////////////////////
                        ISSUER MINTING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Allows issuer to mint shares to specified recipients
     * @dev Can only be called by the issuer through the strategy
     * @param recipient Address to receive the shares
     * @param shares Amount of shares to mint
     */
    function mintShares(address recipient, uint256 shares) external {
        if (msg.sender != strategy) revert OnlyIssuer();
        if (recipient == address(0)) revert InvalidRecipient();
        if (shares == 0) revert InvalidAmount();

        _mint(recipient, shares);

        emit IssuerMint(recipient, shares, tx.origin);
    }

    /**
     * @notice Mint shares for a batch of recipients
     * @dev Can only be called by the issuer through the strategy
     * @param recipients Array of recipient addresses
     * @param shares Array of share amounts aligned with recipients
     */
    function batchMintShares(address[] calldata recipients, uint256[] calldata shares) external {
        // Only strategy can call this
        if (msg.sender != strategy) revert OnlyIssuer();

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

        emit BatchSharesMinted(recipients, shares, totalShares);
    }
}
