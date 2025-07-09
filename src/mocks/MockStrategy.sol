// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IStrategy} from "../strategy/IStrategy.sol";
import {tRWA} from "../token/tRWA.sol";
import {MocktRWA} from "./MocktRWA.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {RoleManager} from "../auth/RoleManager.sol";

/**
 * @title MockStrategy
 * @notice A simple strategy implementation for testing
 */
contract MockStrategy is IStrategy {
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
     * @notice Initialize the strategy
     * @param name_ Name of the token
     * @param symbol_ Symbol of the token
     * @param roleManager_ Address of the role manager
     * @param manager_ Address of the manager
     * @param asset_ Address of the underlying asset
     * @param assetDecimals_ Number of decimals of the asset
     */
    function initialize(
        string calldata name_,
        string calldata symbol_,
        address roleManager_,
        address manager_,
        address asset_,
        uint8 assetDecimals_,
        bytes memory
    ) external override {
        if (_initialized) revert AlreadyInitialized();
        _initialized = true;

        if (manager_ == address(0)) revert InvalidAddress();
        if (asset_ == address(0)) revert InvalidAddress();
        if (roleManager_ == address(0)) revert InvalidAddress();
        // Deploy mock token with no hooks initially (for testing)
        sToken = address(new MocktRWA(name_, symbol_, asset_, assetDecimals_, address(this)));

        deployer = msg.sender;
        manager = manager_;
        asset = asset_;
        assetDecimals = assetDecimals_;
        roleManager = RoleManager(roleManager_);
        _balance = 0;

        emit StrategyInitialized(address(0), manager_, asset_, sToken);
    }

    /**
     * @notice Get the registry contract
     * @return The address of the registry contract
     */
    function registry() external view virtual returns (address) {
        return roleManager.registry();
    }

    /**
     * @notice Set the strategy balance directly (for testing)
     * @param amount The new balance amount
     */
    function setBalance(uint256 amount) external {
        _balance = amount;
    }

    /**
     * @notice Get the balance of the strategy
     * @return The balance of the strategy in the underlying asset
     */
    function balance() external view returns (uint256) {
        // Return actual ERC20 balance instead of _balance for more realistic testing
        return IERC20(asset).balanceOf(address(this));
    }

    function setManager(address newManager) external {
        // In a real implementation, this would be restricted to the appropriate role
        if (msg.sender != manager) revert Unauthorized();

        address oldManager = manager;
        manager = newManager;
        emit ManagerChange(oldManager, newManager);
    }

    /**
     * @notice Call tRWA token with arbitrary data (for testing)
     * @param data The data to call the token with
     */
    function callStrategyToken(bytes calldata data) external returns (bool success, bytes memory returnData) {
        // Only callable by manager
        if (msg.sender != manager && msg.sender != deployer) revert Unauthorized();

        return sToken.call(data);
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
