// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ManagedWithdrawReportedStrategy} from "./ManagedWithdrawRWAStrategy.sol";
import {ForcibleWithdrawRWA} from "../token/ForcibleWithdrawRWA.sol";

/**
 * @title ForcibleWithdrawRWAStrategy
 * @notice Extension of ManagedWithdrawReportedStrategy that deploys ForcibleWithdrawRWA tokens
 * @dev Adds force redemption capabilities while maintaining all signature-based withdrawal functionality
 */
contract ForcibleWithdrawRWAStrategy is ManagedWithdrawReportedStrategy {
    /*//////////////////////////////////////////////////////////////
                        INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploy ForcibleWithdrawRWA token instead of ManagedWithdrawRWA
     * @param name_ Token name
     * @param symbol_ Token symbol
     * @param asset_ Asset address
     * @param assetDecimals_ Asset decimals
     * @return Address of deployed token
     */
    function _deployToken(string calldata name_, string calldata symbol_, address asset_, uint8 assetDecimals_)
        internal
        virtual
        override
        returns (address)
    {
        return address(new ForcibleWithdrawRWA(name_, symbol_, asset_, assetDecimals_, address(this)));
    }

    /*//////////////////////////////////////////////////////////////
                        REDEMPTION LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Force redeem shares from a user without signature
     * @dev Only callable by manager
     * @param shares Amount of shares to force redeem
     * @param account Account to force redeem from
     * @param receiver Receiver of the assets
     * @return assets Amount of assets sent
     */
    function forceRedeem(uint256 shares, address account, address receiver)
        external
        onlyManager
        returns (uint256 assets)
    {
        assets = ForcibleWithdrawRWA(address(sToken)).forceRedeem(shares, account, receiver);
    }

    /**
     * @notice Batch force redeem shares from multiple users
     * @dev Only callable by manager
     * @param shares Array of share amounts
     * @param accounts Array of accounts to redeem from
     * @param receivers Array of asset receivers
     * @return assets Array of asset amounts sent
     */
    function batchForceRedeem(uint256[] calldata shares, address[] calldata accounts, address[] calldata receivers)
        external
        onlyManager
        returns (uint256[] memory assets)
    {
        assets = ForcibleWithdrawRWA(address(sToken)).batchForceRedeem(shares, accounts, receivers);
    }
}
