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
    // Override to deploy ForcibleWithdrawRWA instead of ManagedWithdrawRWA
    function _deployToken(string calldata name_, string calldata symbol_, address asset_, uint8 assetDecimals_)
        internal
        virtual
        override
        returns (address)
    {
        return address(new ForcibleWithdrawRWA(name_, symbol_, asset_, assetDecimals_, address(this)));
    }

    // Force redemption function - callable only by manager
    function forceRedeem(uint256 shares, address account, address receiver)
        external
        onlyManager
        returns (uint256 assets)
    {
        // Call the token's forceRedeem function
        assets = ForcibleWithdrawRWA(address(sToken)).forceRedeem(shares, account, receiver);
    }

    // Batch force redemption - callable only by manager
    function batchForceRedeem(uint256[] calldata shares, address[] calldata accounts, address[] calldata receivers)
        external
        onlyManager
        returns (uint256[] memory assets)
    {
        // Call the token's batchForceRedeem function
        assets = ForcibleWithdrawRWA(address(sToken)).batchForceRedeem(shares, accounts, receivers);
    }
}
