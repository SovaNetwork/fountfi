# MockManagedStrategy
[Git Source](https://github.com/SovaNetwork/fountfi/blob/58164582109e1a7de75ddd7e30bfe628ac79d7fd/src/mocks/MockManagedStrategy.sol)

**Inherits:**
[IStrategy](/src/strategy/IStrategy.sol/interface.IStrategy.md)

A strategy implementation for testing ManagedWithdrawRWA

*This strategy doesn't deploy its own token - it expects the token to be set externally*


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

Initialize the strategy without deploying a token


```solidity
function initialize(
    string calldata,
    string calldata,
    address roleManager_,
    address manager_,
    address asset_,
    uint8,
    bytes memory
) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`||
|`<none>`|`string`||
|`roleManager_`|`address`|Address of the role manager|
|`manager_`|`address`|Address of the manager|
|`asset_`|`address`|Address of the underlying asset|
|`<none>`|`uint8`||
|`<none>`|`bytes`||


### setSToken

Set the sToken address (to be called after ManagedWithdrawRWA is deployed)


```solidity
function setSToken(address token_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token_`|`address`|The address of the ManagedWithdrawRWA token|


### balance

Get the balance of the strategy


```solidity
function balance() external view override returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The balance of the strategy in the underlying asset|


### setManager

Set the manager of the strategy


```solidity
function setManager(address newManager) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newManager`|`address`|The new manager address|


### registry

Get the registry address from roleManager


```solidity
function registry() external view returns (address);
```

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


