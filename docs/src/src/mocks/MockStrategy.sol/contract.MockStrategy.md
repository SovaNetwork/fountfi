# MockStrategy
[Git Source](https://github.com/SovaNetwork/fountfi/blob/58164582109e1a7de75ddd7e30bfe628ac79d7fd/src/mocks/MockStrategy.sol)

**Inherits:**
[IStrategy](/src/strategy/IStrategy.sol/interface.IStrategy.md)

A simple strategy implementation for testing


## State Variables
### manager

```solidity
address public manager;
```


### asset

```solidity
address public asset;
```


### sToken

```solidity
address public sToken;
```


### deployer

```solidity
address public deployer;
```


### controller

```solidity
address public controller;
```


### roleManager

```solidity
RoleManager public roleManager;
```


### _balance

```solidity
uint256 private _balance;
```


### _initialized

```solidity
bool private _initialized;
```


### _controllerConfigured

```solidity
bool private _controllerConfigured;
```


## Functions
### initialize

Initialize the strategy


```solidity
function initialize(
    string calldata name_,
    string calldata symbol_,
    address roleManager_,
    address manager_,
    address asset_,
    uint8 assetDecimals_,
    bytes memory
) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`name_`|`string`|Name of the token|
|`symbol_`|`string`|Symbol of the token|
|`roleManager_`|`address`|Address of the role manager|
|`manager_`|`address`|Address of the manager|
|`asset_`|`address`|Address of the underlying asset|
|`assetDecimals_`|`uint8`|Number of decimals of the asset|
|`<none>`|`bytes`||


### registry

Get the registry contract


```solidity
function registry() external view virtual returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of the registry contract|


### setBalance

Set the strategy balance directly (for testing)


```solidity
function setBalance(uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The new balance amount|


### balance

Get the balance of the strategy


```solidity
function balance() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The balance of the strategy in the underlying asset|


### setManager


```solidity
function setManager(address newManager) external;
```

### callStrategyToken

Call tRWA token with arbitrary data (for testing)


```solidity
function callStrategyToken(bytes calldata data) external returns (bool success, bytes memory returnData);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`data`|`bytes`|The data to call the token with|


### setAllowance

Set the allowance for an ERC20 token


```solidity
function setAllowance(address tokenAddr, address spender, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenAddr`|`address`|The address of the ERC20 token to set the allowance for|
|`spender`|`address`|The address to set the allowance for|
|`amount`|`uint256`|The amount of allowance to set|


