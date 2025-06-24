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

        // Set issuer wallet before calling parent initialize
        if (issuerWallet_ == address(0)) revert InvalidIssuerWallet();
        issuerWallet = issuerWallet_;

        // Call parent initialize with reporter encoded
        super.initialize(name_, symbol_, roleManager_, manager_, asset_, assetDecimals_, abi.encode(reporter_));

        emit SetIssuerWallet(address(0), issuerWallet_);
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
        DirectDepositRWA(sToken).batchMintSharesForDeposit(ids);
    }
}
