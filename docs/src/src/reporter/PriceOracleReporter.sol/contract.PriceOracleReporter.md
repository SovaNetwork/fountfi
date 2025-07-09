# PriceOracleReporter
[Git Source](https://github.com/SovaNetwork/fountfi/blob/58164582109e1a7de75ddd7e30bfe628ac79d7fd/src/reporter/PriceOracleReporter.sol)

**Inherits:**
[IReporter](/src/reporter/IReporter.sol/interface.IReporter.md), Ownable

A reporter contract that allows a trusted party to report the price per share of the strategy
with gradual price transitions to prevent arbitrage opportunities


## State Variables
### currentRound
Current round number


```solidity
uint256 public currentRound;
```


### targetPricePerShare
The target price per share that we're transitioning to


```solidity
uint256 public targetPricePerShare;
```


### transitionStartPrice
The price per share at the start of the current transition


```solidity
uint256 public transitionStartPrice;
```


### lastUpdateAt
The timestamp of the last update


```solidity
uint256 public lastUpdateAt;
```


### maxDeviationPerTimePeriod
Maximum percentage price change allowed per time period (in basis points, e.g., 100 = 1%)


```solidity
uint256 public maxDeviationPerTimePeriod;
```


### deviationTimePeriod
Time period for max deviation (in seconds, e.g., 300 = 5 minutes)


```solidity
uint256 public deviationTimePeriod;
```


### appliedChangeInPeriod
Tracks price changes that have been applied in current period (basis points)


```solidity
uint256 public appliedChangeInPeriod;
```


### periodStartTime
The timestamp when the current tracking period started


```solidity
uint256 public periodStartTime;
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
constructor(
    uint256 initialPricePerShare,
    address updater,
    uint256 _maxDeviationPerTimePeriod,
    uint256 _deviationTimePeriod
);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`initialPricePerShare`|`uint256`|Initial price per share to report (18 decimals)|
|`updater`|`address`|Initial authorized updater address|
|`_maxDeviationPerTimePeriod`|`uint256`|Maximum percentage change per time period (basis points)|
|`_deviationTimePeriod`|`uint256`|Time period in seconds|


### update

Update the reported price per share with gradual transition

*If a transition is already in progress, it will stop the old transition and start a new one.*


```solidity
function update(uint256 newTargetPricePerShare, string calldata source_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newTargetPricePerShare`|`uint256`|The new target price per share to transition to (18 decimals)|
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


### _calculateChangePercent

Calculate percentage change between two prices


```solidity
function _calculateChangePercent(uint256 fromPrice, uint256 toPrice) private pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`fromPrice`|`uint256`|Starting price|
|`toPrice`|`uint256`|Target price|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Change percentage in basis points|


### getCurrentPrice

Get the current price, accounting for gradual transitions


```solidity
function getCurrentPrice() public view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The current price per share|


### getTransitionProgress

Get the progress of the current price transition


```solidity
function getTransitionProgress() external view returns (uint256 percentComplete);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`percentComplete`|`uint256`|The completion percentage in basis points (0-10000)|


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


### setMaxDeviation

Update the maximum deviation parameters

*On calls to setMaxDeviation, the last deviation time period is considered to
have ended, and a new period starts immediately.*


```solidity
function setMaxDeviation(uint256 _maxDeviationPerTimePeriod, uint256 _deviationTimePeriod) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_maxDeviationPerTimePeriod`|`uint256`|New maximum percentage change per time period (basis points)|
|`_deviationTimePeriod`|`uint256`|New time period in seconds|


### forceCompleteTransition

Force complete the current price transition (emergency function)

*Only callable by owner*


```solidity
function forceCompleteTransition() external onlyOwner;
```

## Events
### ForceCompleteTransition

```solidity
event ForceCompleteTransition(uint256 roundNumber, uint256 targetPricePerShare);
```

### PricePerShareUpdated

```solidity
event PricePerShareUpdated(uint256 roundNumber, uint256 targetPricePerShare, uint256 startPricePerShare, string source);
```

### SetUpdater

```solidity
event SetUpdater(address indexed updater, bool isAuthorized);
```

### MaxDeviationUpdated

```solidity
event MaxDeviationUpdated(uint256 oldMaxDeviation, uint256 newMaxDeviation, uint256 timePeriod);
```

## Errors
### InvalidSource

```solidity
error InvalidSource();
```

### InvalidMaxDeviation

```solidity
error InvalidMaxDeviation();
```

### InvalidTimePeriod

```solidity
error InvalidTimePeriod();
```

