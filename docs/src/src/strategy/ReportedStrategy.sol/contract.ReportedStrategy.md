# ReportedStrategy
[Git Source](https://github.com/SovaNetwork/fountfi/blob/58164582109e1a7de75ddd7e30bfe628ac79d7fd/src/strategy/ReportedStrategy.sol)

**Inherits:**
[BasicStrategy](/src/strategy/BasicStrategy.sol/abstract.BasicStrategy.md)

A strategy contract that reports its underlying asset balance through an external oracle using price per share


## State Variables
### reporter
The reporter contract


```solidity
IReporter public reporter;
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
    bytes memory initData
) public virtual override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`name_`|`string`|The name of the strategy|
|`symbol_`|`string`|The symbol of the strategy|
|`roleManager_`|`address`|The role manager address|
|`manager_`|`address`|The manager address|
|`asset_`|`address`|The asset address|
|`assetDecimals_`|`uint8`|The asset decimals|
|`initData`|`bytes`|Initialization data|


### balance

Get the balance of the strategy


```solidity
function balance() external view override returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The balance of the strategy in the underlying asset|


### pricePerShare

Get the current price per share from the reporter


```solidity
function pricePerShare() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The price per share in 18 decimal format|


### setReporter

Set the reporter contract


```solidity
function setReporter(address _reporter) external onlyManager;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_reporter`|`address`|The new reporter contract|


## Events
### SetReporter

```solidity
event SetReporter(address indexed reporter);
```

## Errors
### InvalidReporter

```solidity
error InvalidReporter();
```

