# IRegistry
[Git Source](https://github.com/SovaNetwork/fountfi/blob/58164582109e1a7de75ddd7e30bfe628ac79d7fd/src/registry/IRegistry.sol)

Interface for the Registry contract

*The Registry contract is used to register strategies, hooks, and assets
and to deploy new strategies and tokens.*


## Functions
### conduit


```solidity
function conduit() external view returns (address);
```

### allowedStrategies


```solidity
function allowedStrategies(address implementation) external view returns (bool);
```

### allowedHooks


```solidity
function allowedHooks(address implementation) external view returns (bool);
```

### allowedAssets


```solidity
function allowedAssets(address asset) external view returns (uint8);
```

### isStrategy


```solidity
function isStrategy(address implementation) external view returns (bool);
```

### allStrategies


```solidity
function allStrategies() external view returns (address[] memory);
```

### isStrategyToken


```solidity
function isStrategyToken(address token) external view returns (bool);
```

### allStrategyTokens


```solidity
function allStrategyTokens() external view returns (address[] memory tokens);
```

### deploy


```solidity
function deploy(
    address _implementation,
    string memory _name,
    string memory _symbol,
    address _asset,
    address _manager,
    bytes memory _initData
) external returns (address strategy, address token);
```

## Events
### SetStrategy

```solidity
event SetStrategy(address indexed implementation, bool allowed);
```

### SetHook

```solidity
event SetHook(address indexed implementation, bool allowed);
```

### SetAsset

```solidity
event SetAsset(address indexed asset, uint8 decimals);
```

### Deploy

```solidity
event Deploy(address indexed strategy, address indexed sToken, address indexed asset);
```

### DeployWithController

```solidity
event DeployWithController(address indexed strategy, address indexed sToken, address indexed controller);
```

## Errors
### ZeroAddress

```solidity
error ZeroAddress();
```

### UnauthorizedStrategy

```solidity
error UnauthorizedStrategy();
```

### UnauthorizedHook

```solidity
error UnauthorizedHook();
```

### UnauthorizedAsset

```solidity
error UnauthorizedAsset();
```

### InvalidInitialization

```solidity
error InvalidInitialization();
```

