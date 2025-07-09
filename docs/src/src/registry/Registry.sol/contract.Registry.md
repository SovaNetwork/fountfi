# Registry
[Git Source](https://github.com/SovaNetwork/fountfi/blob/58164582109e1a7de75ddd7e30bfe628ac79d7fd/src/registry/Registry.sol)

**Inherits:**
[IRegistry](/src/registry/IRegistry.sol/interface.IRegistry.md), [RoleManaged](/src/auth/RoleManaged.sol/abstract.RoleManaged.md)

Central registry for strategies, rules, assets, and reporters

*Uses minimal proxy pattern for cloning templates*


## State Variables
### conduit
Singleton contracts


```solidity
address public immutable override conduit;
```


### allowedStrategies
Registry mappings


```solidity
mapping(address => bool) public override allowedStrategies;
```


### allowedHooks

```solidity
mapping(address => bool) public override allowedHooks;
```


### allowedAssets
asset => decimals (0 if not allowed)


```solidity
mapping(address => uint8) public override allowedAssets;
```


### _allStrategies
Deployed strategies


```solidity
address[] internal _allStrategies;
```


### isStrategy

```solidity
mapping(address => bool) public override isStrategy;
```


## Functions
### constructor

Constructor


```solidity
constructor(address _roleManager) RoleManaged(_roleManager);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_roleManager`|`address`|Address of the role manager - singleton contract for managing protocol roles|


### setStrategy

Register a strategy implementation template


```solidity
function setStrategy(address implementation, bool allowed) external onlyRoles(roleManager.STRATEGY_ADMIN());
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`implementation`|`address`|Address of the strategy implementation|
|`allowed`|`bool`|Whether the implementation is allowed|


### setHook

Register an operation hook implementation template


```solidity
function setHook(address implementation, bool allowed) external onlyRoles(roleManager.RULES_ADMIN());
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`implementation`|`address`|Address of the hook implementation|
|`allowed`|`bool`|Whether the implementation is allowed|


### setAsset

Register an asset


```solidity
function setAsset(address asset, uint8 decimals) external onlyRoles(roleManager.PROTOCOL_ADMIN());
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|Address of the asset|
|`decimals`|`uint8`|Decimals of the asset (set 0 to disallow)|


### isStrategyToken

Check if a token is a tRWA token


```solidity
function isStrategyToken(address token) external view override returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Address of the token|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool True if the token is a tRWA token, false otherwise|


### allStrategyTokens

Get all tRWA tokens


```solidity
function allStrategyTokens() external view override returns (address[] memory tokens);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`tokens`|`address[]`|Array of tRWA token addresses|


### allStrategies

Get all strategies


```solidity
function allStrategies() external view override returns (address[] memory strategies);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`strategies`|`address[]`|Array of strategy addresses|


### deploy

Deploy a new strategy and its associated tRWA token


```solidity
function deploy(
    address _strategyImpl,
    string memory _name,
    string memory _symbol,
    address _asset,
    address _manager,
    bytes memory _initData
) external override onlyRoles(roleManager.STRATEGY_OPERATOR()) returns (address strategy, address token);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_strategyImpl`|`address`|Address of the strategy implementation|
|`_name`|`string`|Token name|
|`_symbol`|`string`|Token symbol|
|`_asset`|`address`|Asset address|
|`_manager`|`address`|Manager address for the strategy|
|`_initData`|`bytes`|Initialization data|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`strategy`|`address`|Address of the deployed strategy|
|`token`|`address`|Address of the deployed tRWA token|


