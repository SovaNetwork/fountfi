// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ManagedWithdrawReportedStrategy} from "./ManagedWithdrawRWAStrategy.sol";
import {DirectManagedRWA} from "../token/DirectManagedRWA.sol";
import {IDirectDepositStrategy} from "./IDirectDepositStrategy.sol";
import {IStrategy} from "./IStrategy.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {Conduit} from "../conduit/Conduit.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {RoleManaged} from "../auth/RoleManaged.sol";

/**
 * @title DirectManagedStrategy
 * @notice Strategy that combines direct deposits to issuer wallet with managed withdrawals
 * @dev Inherits from ManagedWithdrawReportedStrategy and adds direct deposit functionality
 */
contract DirectManagedStrategy is ManagedWithdrawReportedStrategy, IDirectDepositStrategy {
    using SafeTransferLib for address;

    event TokenInitialized(address indexed token);

    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice The issuer's wallet address where deposits are sent
    address public issuerWallet;

    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initialize with issuer wallet - call this instead of initialize
     * @param name_ Name of the token
     * @param symbol_ Symbol of the token
     * @param roleManager_ Address of the role manager
     * @param manager_ Address of the manager
     * @param asset_ Address of the underlying asset
     * @param assetDecimals_ Decimals of the asset
     * @param extraData Encoded reporter and issuer wallet addresses
     */
    function initialize(
        string calldata name_,
        string calldata symbol_,
        address roleManager_,
        address manager_,
        address asset_,
        uint8 assetDecimals_,
        bytes memory extraData
    ) public override(ManagedWithdrawReportedStrategy, IStrategy) {
        // Decode reporter and issuer wallet from extraData
        (address reporter_, address issuerWallet_) = abi.decode(extraData, (address, address));

        // Set issuer wallet
        if (issuerWallet_ == address(0)) revert InvalidIssuerWallet();
        issuerWallet = issuerWallet_;

        // Call parent initialize with reporter encoded
        super.initialize(name_, symbol_, roleManager_, manager_, asset_, assetDecimals_, abi.encode(reporter_));

        emit SetIssuerWallet(address(0), issuerWallet_);
    }

    /*//////////////////////////////////////////////////////////////
                            DEPLOYMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploy a new DirectManagedRWA token
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
        // DirectManagedRWA newToken = new DirectManagedRWA(name_, symbol_, asset_, assetDecimals_, address(this));
        address newToken = address(0);

        return address(newToken);
    }

    /**
     * @notice Initialization of the tRWA token called by the manager. Token must be separately deployed.
     * @dev TEMPORARY solution to contract size issues
     * @param token Address of the already deployed token
     */
    function initializeToken(address token) external onlyRoles(roleManager.STRATEGY_ADMIN()) {
        // Initialize the token with the issuer wallet
        if (sToken != address(0)) revert TokenAlreadyDeployed();
        if (token == address(0)) revert InvalidAddress();

        sToken = token;

        emit TokenInitialized(sToken);
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

        emit SetIssuerWallet(oldWallet, newWallet);
    }

    /*//////////////////////////////////////////////////////////////
                        SHARE MINTING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mint shares for a batch of deposits
     * @param ids Array of deposit IDs
     */
    function batchMintShares(bytes32[] calldata ids) external override onlyManager {
        DirectManagedRWA(sToken).batchMintSharesForDeposit(ids);
    }
}
