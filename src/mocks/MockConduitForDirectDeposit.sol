// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

/**
 * @title MockConduitForDirectDeposit
 * @notice Mock conduit that allows transfers to any destination for testing DirectDepositRWA
 */
contract MockConduitForDirectDeposit {
    using SafeTransferLib for address;

    function collectDeposit(address token, address from, address to, uint256 amount) external returns (bool) {
        // In the mock, we just transfer without checks
        token.safeTransferFrom(from, to, amount);
        return true;
    }
}
