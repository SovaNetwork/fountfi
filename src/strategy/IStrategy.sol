// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

/**
 * @title IStrategy
 * @notice Interface for tRWA investment strategies
 * @dev Defines the interface for strategies that manage tRWA token assets
 */
interface IStrategy {
    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidAddress();
    error InvalidRules();
    error Unauthorized();
    error CallRevert(bytes returnData);
    error AlreadyInitialized();
    error TokenAlreadyDeployed();
    error CannotCallToken();

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event PendingAdminChange(address indexed oldAdmin, address indexed newAdmin);
    event AdminChange(address indexed oldAdmin, address indexed newAdmin);
    event NoAdminChange(address indexed oldAdmin, address indexed cancelledAdmin);
    event ManagerChange(address indexed oldManager, address indexed newManager);
    event Call(address indexed target, uint256 value, bytes data);
    event StrategyInitialized(address indexed admin, address indexed manager, address indexed asset, address sToken);
    event ControllerConfigured(address indexed controller);

    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    function initialize(
        string calldata name,
        string calldata symbol,
        address roleManager,
        address manager,
        address asset,
        uint8 assetDecimals,
        bytes memory initData
    ) external;

    /*//////////////////////////////////////////////////////////////
                             MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function manager() external view returns (address);
    function setManager(address newManager) external;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function asset() external view returns (address);
    function assetDecimals() external view returns (uint8);
    function sToken() external view returns (address);
    function balance() external view returns (uint256);
}
