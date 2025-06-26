// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ManagedWithdrawRWA} from "./ManagedWithdrawRWA.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

contract ForcibleWithdrawRWA is ManagedWithdrawRWA {
    using SafeTransferLib for address;

    // Events
    event ForcedWithdrawal(
        address indexed account, address indexed receiver, uint256 shares, uint256 assets, address indexed executor
    );

    // Additional errors
    error InvalidAmount();
    error ArrayLengthMismatch();

    // Constructor
    constructor(string memory name_, string memory symbol_, address asset_, uint8 assetDecimals_, address strategy_)
        ManagedWithdrawRWA(name_, symbol_, asset_, assetDecimals_, strategy_)
    {}

    // Force-out function - only callable by strategy
    function forceRedeem(uint256 shares, address account, address receiver)
        external
        onlyStrategy
        returns (uint256 assets)
    {
        if (account == address(0)) revert InvalidAddress();
        if (receiver == address(0)) revert InvalidAddress();
        if (shares == 0) revert InvalidAmount();

        uint256 maxShares = balanceOf(account);
        if (shares > maxShares) {
            shares = maxShares; // Cap at user's balance
        }

        // Execute the forced redemption
        assets = convertToAssets(shares);

        // Bypass the standard withdrawal flow to avoid allowance checks
        // First burn shares from the account
        _burn(account, shares);

        // Get assets from strategy
        _collect(assets);

        // Transfer the assets to the receiver
        asset().safeTransfer(receiver, assets);

        // Emit standard Withdraw event for ERC4626 compliance
        emit Withdraw(msg.sender, receiver, account, assets, shares);

        // Emit specific ForcedWithdrawal event for tracking
        emit ForcedWithdrawal(account, receiver, shares, assets, msg.sender);

        return assets;
    }

    // Batch force redemption for efficiency
    function batchForceRedeem(uint256[] calldata shares, address[] calldata accounts, address[] calldata receivers)
        external
        onlyStrategy
        returns (uint256[] memory assets)
    {
        uint256 length = accounts.length;
        if (length != shares.length || length != receivers.length) {
            revert ArrayLengthMismatch();
        }

        assets = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            // Inline the logic to avoid external call
            uint256 userShares = shares[i];
            address account = accounts[i];
            address receiver = receivers[i];

            if (account == address(0)) revert InvalidAddress();
            if (receiver == address(0)) revert InvalidAddress();
            if (userShares == 0) revert InvalidAmount();

            uint256 maxShares = balanceOf(account);
            if (userShares > maxShares) {
                userShares = maxShares;
            }

            uint256 userAssets = convertToAssets(userShares);

            // Bypass the standard withdrawal flow for forced redemption
            _burn(account, userShares);
            _collect(userAssets);
            asset().safeTransfer(receiver, userAssets);

            // Emit events
            emit Withdraw(msg.sender, receiver, account, userAssets, userShares);
            emit ForcedWithdrawal(account, receiver, userShares, userAssets, msg.sender);

            assets[i] = userAssets;
        }

        return assets;
    }
}
