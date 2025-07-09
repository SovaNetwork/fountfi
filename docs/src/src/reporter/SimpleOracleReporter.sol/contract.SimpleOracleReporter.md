# SimpleOracleReporter
[Git Source](https://github.com/SovaNetwork/fountfi/blob/58164582109e1a7de75ddd7e30bfe628ac79d7fd/src/reporter/SimpleOracleReporter.sol)

**Inherits:**
[IReporter](/src/reporter/IReporter.sol/interface.IReporter.md), Ownable

A reporter contract that allows a trusted party to report the price per share of the strategy


## State Variables
### currentRound
Current round number


```solidity
uint256 public currentRound;
```


### pricePerShare
The current price per share (in wei, 18 decimals)


```solidity
uint256 public pricePerShare;
```


### lastUpdateAt
The timestamp of the last update


```solidity
uint256 public lastUpdateAt;
```


### authorizedUpdaters
Mapping of authorized updaters


```solidity
mapping(address => bool) public authorizedUpdaters;
```


## Functions
### constructor

Contract constructor


```solidity
constructor(uint256 initialPricePerShare, address updater);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`initialPricePerShare`|`uint256`|Initial price per share to report (18 decimals)|
|`updater`|`address`||


### update

Update the reported price per share


```solidity
function update(uint256 newPricePerShare, string calldata source_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newPricePerShare`|`uint256`|The new price per share to report (18 decimals)|
|`source_`|`string`|The source of the price update|


### report

Report the current price per share


```solidity
function report() external view override returns (bytes memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The encoded current price per share|


### setUpdater

Set whether an address is authorized to update values


```solidity
function setUpdater(address updater, bool isAuthorized) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`updater`|`address`|Address to modify authorization for|
|`isAuthorized`|`bool`|Whether the address should be authorized|


## Events
### PricePerShareUpdated

```solidity
event PricePerShareUpdated(uint256 roundNumber, uint256 pricePerShare, string source);
```

### SetUpdater

```solidity
event SetUpdater(address indexed updater, bool isAuthorized);
```

## Errors
### InvalidSource

```solidity
error InvalidSource();
```

