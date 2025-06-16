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
     * @param initData Encoded issuer wallet address
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
        // Prevent re-initialization
        if (_initialized) revert AlreadyInitialized();
        _initialized = true;

        if (manager_ == address(0)) revert InvalidAddress();
        if (asset_ == address(0)) revert InvalidAddress();

        // Decode issuer wallet from initData
        address issuerWallet_ = abi.decode(initData, (address));
        if (issuerWallet_ == address(0)) revert InvalidIssuerWallet();

        // Set up strategy configuration
        manager = manager_;
        asset = asset_;
        issuerWallet = issuerWallet_;
        _initializeRoleManager(roleManager_);

        // Deploy DirectDepositRWA token
        sToken = _deployToken(name_, symbol_, asset, assetDecimals_);

        emit StrategyInitialized(address(0), manager, asset, sToken);
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
}
