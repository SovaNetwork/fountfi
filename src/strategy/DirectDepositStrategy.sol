// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ReportedStrategy} from "./ReportedStrategy.sol";
import {IStrategy} from "./IStrategy.sol";
import {IDirectDepositStrategy} from "./IDirectDepositStrategy.sol";
import {DirectDepositRWA} from "../token/DirectDepositRWA.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ERC20} from "solady/tokens/ERC20.sol";

/**
 * @title DirectDepositStrategy
 * @notice Strategy that supports direct deposits to issuer wallet
 * @dev Deploys DirectDepositRWA token instead of standard tRWA
 */
contract DirectDepositStrategy is ReportedStrategy, IDirectDepositStrategy {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice The issuer's wallet address where deposits are sent
    address public issuerWallet;

    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initialize the strategy with issuer wallet configuration
     * @param name_ Name of the token
     * @param symbol_ Symbol of the token
     * @param roleManager_ Address of the role manager
     * @param manager_ Address of the manager
     * @param asset_ Address of the underlying asset
     * @param assetDecimals_ Decimals of the asset
     * @param initData Encoded reporter and issuer wallet addresses
     */
    function initialize(
        string calldata name_,
        string calldata symbol_,
        address roleManager_,
        address manager_,
        address asset_,
        uint8 assetDecimals_,
        bytes memory initData
    ) public virtual override(ReportedStrategy, IStrategy) {
        // Decode both reporter and issuer wallet from initData
        (address reporter_, address issuerWallet_) = abi.decode(initData, (address, address));
        if (issuerWallet_ == address(0)) revert InvalidIssuerWallet();

        // Set issuer wallet before calling parent initialize
        issuerWallet = issuerWallet_;

        // Call parent initialize with reporter encoded
        super.initialize(name_, symbol_, roleManager_, manager_, asset_, assetDecimals_, abi.encode(reporter_));

        emit IssuerWalletSet(address(0), issuerWallet_);
    }

    /**
     * @notice Deploy a new DirectDepositRWA token
     * @param name_ Name of the token
     * @param symbol_ Symbol of the token
     * @param asset_ Address of the underlying asset
     * @param assetDecimals_ Decimals of the asset
     */
    function _deployToken(string calldata name_, string calldata symbol_, address asset_, uint8 assetDecimals_)
        internal
        virtual
        override
        returns (address)
    {
        DirectDepositRWA newToken = new DirectDepositRWA(name_, symbol_, asset_, assetDecimals_, address(this));

        return address(newToken);
    }

    /*//////////////////////////////////////////////////////////////
                        ISSUER WALLET MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Set a new issuer wallet address
     * @param newWallet The new issuer wallet address
     */
    function setIssuerWallet(address newWallet) external override onlyManager {
        if (newWallet == address(0)) revert InvalidIssuerWallet();

        address oldWallet = issuerWallet;
        issuerWallet = newWallet;

        emit IssuerWalletSet(oldWallet, newWallet);
    }

    /*//////////////////////////////////////////////////////////////
                        SHARE MINTING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mint shares to a specified recipient
     * @dev Can only be called by authorized roles
     * @param recipient Address to receive the shares
     * @param shares Amount of shares to mint
     */
    function mintShares(address recipient, uint256 shares) external override onlyManager {
        DirectDepositRWA(sToken).mintShares(recipient, shares);
    }

    /**
     * @notice Mint shares for a batch of recipients
     * @dev Can only be called by authorized roles
     * @param recipients Array of recipient addresses
     * @param shares Array of share amounts aligned with recipients
     */
    function batchMintShares(address[] calldata recipients, uint256[] calldata shares) external override onlyManager {
        DirectDepositRWA(sToken).batchMintShares(recipients, shares);
    }

    /*//////////////////////////////////////////////////////////////
                    DEPOSIT MANAGEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Accept a pending deposit and mint shares
     * @param depositId The deposit ID to accept
     */
    function acceptDeposit(bytes32 depositId) external override onlyManager {
        DirectDepositRWA(sToken).acceptDeposit(depositId);
    }

    /**
     * @notice Accept multiple pending deposits as a batch
     * @param depositIds Array of deposit IDs to accept
     */
    function batchAcceptDeposits(bytes32[] calldata depositIds) external override onlyManager {
        DirectDepositRWA(sToken).batchAcceptDeposits(depositIds);
    }

    /**
     * @notice Refund a pending deposit
     * @dev Must call fundRefund first to ensure funds are available
     * @param depositId The deposit ID to refund
     */
    function refundDeposit(bytes32 depositId) external override onlyManager {
        DirectDepositRWA(sToken).refundDeposit(depositId);
    }

    /**
     * @notice Sets the period after which deposits expire
     * @param newExpirationPeriod New expiration period in seconds
     */
    function setDepositExpirationPeriod(uint256 newExpirationPeriod) external override onlyManager {
        DirectDepositRWA(sToken).setDepositExpirationPeriod(newExpirationPeriod);
    }

    /**
     * @notice Fund the token contract for refunds
     * @dev Transfer assets from issuer wallet to token for refunding deposits
     * @param amount Amount of assets to transfer
     */
    function fundRefund(uint256 amount) external onlyManager {
        SafeTransferLib.safeTransferFrom(asset, issuerWallet, sToken, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        WITHDRAWAL SUPPORT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Transfer assets from issuer wallet to strategy for withdrawals
     * @dev Issuer must approve strategy to spend assets before calling
     * @param amount Amount of assets to transfer
     */
    function fundWithdrawals(uint256 amount) external onlyManager {
        SafeTransferLib.safeTransferFrom(asset, issuerWallet, address(this), amount);
    }
}
