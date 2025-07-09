# IStrategy
[Git Source](https://github.com/SovaNetwork/fountfi/blob/58164582109e1a7de75ddd7e30bfe628ac79d7fd/src/strategy/IStrategy.sol)

Interface for tRWA investment strategies

*Defines the interface for strategies that manage tRWA token assets*


## Functions
### initialize


```solidity
function initialize(
    string calldata name,
    string calldata symbol,
    address roleManager,
    address manager,
    address asset,
    uint8 assetDecimals,
    bytes memory initData
) external;
```

### manager


```solidity
function manager() external view returns (address);
```

### setManager


```solidity
function setManager(address newManager) external;
```

### asset


```solidity
function asset() external view returns (address);
```

### sToken


```solidity
function sToken() external view returns (address);
```

### balance


```solidity
function balance() external view returns (uint256);
```

## Events
### PendingAdminChange

```solidity
event PendingAdminChange(address indexed oldAdmin, address indexed newAdmin);
```

### AdminChange

```solidity
event AdminChange(address indexed oldAdmin, address indexed newAdmin);
```

### NoAdminChange

```solidity
event NoAdminChange(address indexed oldAdmin, address indexed cancelledAdmin);
```

### ManagerChange

```solidity
event ManagerChange(address indexed oldManager, address indexed newManager);
```

### Call

```solidity
event Call(address indexed target, uint256 value, bytes data);
```

### StrategyInitialized

```solidity
event StrategyInitialized(address indexed admin, address indexed manager, address indexed asset, address sToken);
```

### ControllerConfigured

```solidity
event ControllerConfigured(address indexed controller);
```

## Errors
### InvalidAddress

```solidity
error InvalidAddress();
```

### InvalidRules

```solidity
error InvalidRules();
```

### Unauthorized

```solidity
error Unauthorized();
```

### CallRevert

```solidity
error CallRevert(bytes returnData);
```

### AlreadyInitialized

```solidity
error AlreadyInitialized();
```

### TokenAlreadyDeployed

```solidity
error TokenAlreadyDeployed();
```

### CannotCallToken

```solidity
error CannotCallToken();
```

