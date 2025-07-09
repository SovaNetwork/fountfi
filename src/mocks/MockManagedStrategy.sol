// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IStrategy} from "../strategy/IStrategy.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {RoleManager} from "../auth/RoleManager.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

/**
 * @title MockManagedStrategy
 * @notice A strategy implementation for testing ManagedWithdrawRWA
 * @dev This strategy doesn't deploy its own token - it expects the token to be set externally
 */
contract MockManagedStrategy is IStrategy {
    using SafeTransferLib for address;

    address public manager;
    address public asset;
    uint8 public assetDecimals;
    address public sToken;
    address public deployer;
    address public controller;
    RoleManager public roleManager;
    uint256 private _balance;
    bool private _initialized;
    bool private _controllerConfigured;

    /**
     * @notice Initialize the strategy without deploying a token
     * @param roleManager_ Address of the role manager
     * @param manager_ Address of the manager
     * @param asset_ Address of the underlying asset
     */
    function initialize(
        string calldata,
        string calldata,
        address roleManager_,
        address manager_,
        address asset_,
        uint8,
        bytes memory
    ) external override {
        if (_initialized) revert AlreadyInitialized();
        _initialized = true;

        if (manager_ == address(0)) revert InvalidAddress();
        if (asset_ == address(0)) revert InvalidAddress();
        if (roleManager_ == address(0)) revert InvalidAddress();

        manager = manager_;
        asset = asset_;
        assetDecimals = 18;

        roleManager = RoleManager(roleManager_);
        deployer = msg.sender;

        // Don't deploy a token - it will be set externally
        emit StrategyInitialized(address(0), manager, asset, address(0));
    }

    /**
     * @notice Set the sToken address (to be called after ManagedWithdrawRWA is deployed)
     * @param token_ The address of the ManagedWithdrawRWA token
     */
    function setSToken(address token_) external {
        if (sToken != address(0)) revert TokenAlreadyDeployed();
        if (token_ == address(0)) revert InvalidAddress();
        sToken = token_;
    }

    /**
     * @notice Get the balance of the strategy
     * @return The balance of the strategy in the underlying asset
     */
    function balance() external view override returns (uint256) {
        return IERC20(asset).balanceOf(address(this));
    }

    /**
     * @notice Set the manager of the strategy
     * @param newManager The new manager address
     */
    function setManager(address newManager) external override {
        if (msg.sender != manager) revert Unauthorized();
        manager = newManager;
        emit ManagerChange(manager, newManager);
    }

    /**
     * @notice Get the registry address from roleManager
     */
    function registry() external view returns (address) {
        return roleManager.registry();
    }

    /**
     * @notice Set the allowance for an ERC20 token
     * @param tokenAddr The address of the ERC20 token to set the allowance for
     * @param spender The address to set the allowance for
     * @param amount The amount of allowance to set
     */
    function setAllowance(address tokenAddr, address spender, uint256 amount) external {
        if (msg.sender != manager) revert Unauthorized();
        IERC20(tokenAddr).approve(spender, amount);
    }
}
