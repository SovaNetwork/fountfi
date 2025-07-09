# MockReporter
[Git Source](https://github.com/SovaNetwork/fountfi/blob/58164582109e1a7de75ddd7e30bfe628ac79d7fd/src/mocks/MockReporter.sol)

**Inherits:**
[IReporter](/src/reporter/IReporter.sol/interface.IReporter.md)

A simple reporter implementation for testing


## State Variables
### _value

```solidity
uint256 private _value;
```


## Functions
### constructor


```solidity
constructor(uint256 initialValue);
```

### setValue

Set a new value for the reporter


```solidity
function setValue(uint256 newValue) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newValue`|`uint256`|The new value to report|


### report

Report the current value


```solidity
function report() external view override returns (bytes memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The encoded current value|


