// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ManagedWithdrawRWA} from "./ManagedWithdrawRWA.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

/**
 * @title ForcibleWithdrawRWA
 * @notice Extension of ManagedWithdrawRWA that allows managers to force withdrawals without user signatures
 * @dev Implements force redemption functionality while maintaining ERC4626 compliance
 */
contract ForcibleWithdrawRWA is ManagedWithdrawRWA {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidAmount();
    error ArrayLengthMismatch();

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event ForcedWithdrawal(
        address indexed account, address indexed receiver, uint256 shares, uint256 assets, address indexed executor
    );

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor
     * @param name_ Token name
     * @param symbol_ Token symbol
     * @param asset_ Asset address
     * @param assetDecimals_ Decimals of the asset token
     * @param strategy_ Strategy address
     */
    constructor(string memory name_, string memory symbol_, address asset_, uint8 assetDecimals_, address strategy_)
        ManagedWithdrawRWA(name_, symbol_, asset_, assetDecimals_, strategy_)
    {}

    /*//////////////////////////////////////////////////////////////
                        FORCE REDEMPTION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Force redeem shares from a user without requiring their signature
     * @dev Only callable by strategy (which enforces manager-only access)
     * @param shares Amount of shares to force redeem
     * @param account Address of the account to force redeem from
     * @param receiver Address to receive the redeemed assets
     * @return assets Amount of assets sent to receiver
     */
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

        // Bypass the standard withdrawal flow to avoid allowance checks and hooks
        _burn(account, shares);
        _collect(assets);
        asset().safeTransfer(receiver, assets);

        // Emit events
        emit Withdraw(msg.sender, receiver, account, assets, shares);
        emit ForcedWithdrawal(account, receiver, shares, assets, msg.sender);

        return assets;
    }

    /**
     * @notice Batch force redeem shares from multiple users
     * @dev Only callable by strategy (which enforces manager-only access)
     * @param shares Array of share amounts to force redeem
     * @param accounts Array of accounts to force redeem from
     * @param receivers Array of addresses to receive the redeemed assets
     * @return assets Array of asset amounts sent to receivers
     */
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

            // Bypass the standard withdrawal flow
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
