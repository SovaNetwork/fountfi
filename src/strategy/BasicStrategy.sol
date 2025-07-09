// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IStrategy} from "./IStrategy.sol";
import {tRWA} from "../token/tRWA.sol";
import {CloneableRoleManaged} from "../auth/CloneableRoleManaged.sol";

/**
 * @title BasicStrategy
 * @notice A basic strategy contract for managing tRWA assets
 * @dev Each strategy deploys its own tRWA token (sToken)
 *
 * Consider for future: Making BasicStrategy an ERC4337-compatible smart account
 */
abstract contract BasicStrategy is IStrategy, CloneableRoleManaged {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice The manager of the strategy
    address public manager;
    /// @notice The asset of the strategy
    address public asset;
    /// @notice The decimals of the asset
    uint8 public assetDecimals;
    /// @notice The sToken of the strategy
    address public sToken;

    /// @notice Initialization flags to prevent re-initialization
    bool internal _initialized;

    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initialize the strategy
     * @param name_ Name of the token
     * @param symbol_ Symbol of the token
     * @param roleManager_ Address of the role manager
     * @param manager_ Address of the manager
     * @param asset_ Address of the underlying asset
     * @param assetDecimals_ Decimals of the asset
     */
    function initialize(
        string calldata name_,
        string calldata symbol_,
        address roleManager_,
        address manager_,
        address asset_,
        uint8 assetDecimals_,
        bytes memory // initData
    ) public virtual override {
        // Prevent re-initialization
        if (_initialized) revert AlreadyInitialized();
        _initialized = true;

        if (manager_ == address(0)) revert InvalidAddress();
        if (asset_ == address(0)) revert InvalidAddress();

        // Set up strategy configuration
        // Unlike other protocol roles, only a single manager is allowed
        manager = manager_;
        asset = asset_;
        assetDecimals = assetDecimals_;
        _initializeRoleManager(roleManager_);

        sToken = _deployToken(name_, symbol_, asset, assetDecimals_);

        emit StrategyInitialized(address(0), manager, asset, sToken);
    }

    /**
     * @notice Deploy a new tRWA token
     * @param name_ Name of the token
     * @param symbol_ Symbol of the token
     * @param asset_ Address of the underlying asset
     * @param assetDecimals_ Decimals of the asset
     */
    function _deployToken(string calldata name_, string calldata symbol_, address asset_, uint8 assetDecimals_)
        internal
        virtual
        returns (address)
    {
        tRWA newToken = new tRWA(name_, symbol_, asset_, assetDecimals_, address(this));

        return address(newToken);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Allow admin to change the manager
     * @param newManager The new manager
     */
    function setManager(address newManager) external onlyRoles(roleManager.STRATEGY_ADMIN()) {
        // Can set to 0 to disable manager
        manager = newManager;

        emit ManagerChange(manager, newManager);
    }

    /*//////////////////////////////////////////////////////////////
                            ASSET MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get the balance of the strategy
     * @return The balance of the strategy in the underlying asset
     */
    function balance() external view virtual returns (uint256);

    /**
     * @notice Send owned ETH to an address
     * @param to The address to send the ETH to
     */
    function sendETH(address to) external onlyManager {
        to.call{value: address(this).balance}("");
    }

    /**
     * @notice Send owned ERC20 tokens to an address
     * @param tokenAddr The address of the ERC20 token to send
     * @param to The address to send the tokens to
     * @param amount The amount of tokens to send
     */
    function sendToken(address tokenAddr, address to, uint256 amount) external onlyManager {
        tokenAddr.safeTransfer(to, amount);
    }

    /**
     * @notice Pull ERC20 tokens from an external contract into this contract
     * @param tokenAddr The address of the ERC20 token to pull
     * @param from The address to pull the tokens from
     * @param amount The amount of tokens to pull
     */
    function pullToken(address tokenAddr, address from, uint256 amount) external onlyManager {
        tokenAddr.safeTransferFrom(from, address(this), amount);
    }

    /**
     * @notice Set the allowance for an ERC20 token
     * @param tokenAddr The address of the ERC20 token to set the allowance for
     * @param spender The address to set the allowance for
     * @param amount The amount of allowance to set
     */
    function setAllowance(address tokenAddr, address spender, uint256 amount) external onlyManager {
        tokenAddr.safeApproveWithRetry(spender, amount);
    }

    /**
     * @notice Call the strategy token
     * @dev Used for configuring token hooks
     * @param data The calldata to call the strategy token with
     */
    function callStrategyToken(bytes calldata data) external onlyRoles(roleManager.STRATEGY_ADMIN()) {
        (bool success, bytes memory returnData) = sToken.call(data);

        if (!success) {
            revert CallRevert(returnData);
        }

        emit Call(sToken, 0, data);
    }

    /**
     * @notice Execute arbitrary transactions on behalf of the strategy
     * @param target Address of the contract to call
     * @param value Amount of ETH to send
     * @param data Calldata to send
     * @return success Whether the call succeeded
     * @return returnData The return data from the call
     */
    function call(address target, uint256 value, bytes calldata data)
        external
        onlyManager
        returns (bool success, bytes memory returnData)
    {
        if (target == address(0) || target == address(this)) revert InvalidAddress();
        if (target == sToken) revert CannotCallToken();

        (success, returnData) = target.call{value: value}(data);
        if (!success) {
            revert CallRevert(returnData);
        }

        emit Call(target, value, data);
    }

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyManager() {
        if (msg.sender != manager) revert Unauthorized();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            FALLBACK
    //////////////////////////////////////////////////////////////*/

    receive() external payable {}
}
