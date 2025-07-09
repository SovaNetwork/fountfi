# ParameterTrackingHook
[Git Source](https://github.com/SovaNetwork/fountfi/blob/58164582109e1a7de75ddd7e30bfe628ac79d7fd/src/mocks/hooks/ParameterTrackingHook.sol)

**Inherits:**
[IHook](/src/hooks/IHook.sol/interface.IHook.md)

Mock hook that tracks all parameters passed to it for testing verification


## State Variables
### calls

```solidity
TrackedCall[] public calls;
```


## Functions
### onBeforeDeposit

Tracks deposit parameters and returns approval


```solidity
function onBeforeDeposit(address token, address user, uint256 assets, address receiver)
    external
    returns (HookOutput memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`HookOutput`|HookOutput with approved=true and empty message|


### onBeforeWithdraw

Tracks withdraw parameters and returns approval


```solidity
function onBeforeWithdraw(address token, address by, uint256 assets, address to, address owner)
    external
    returns (HookOutput memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`HookOutput`|HookOutput with approved=true and empty message|


### onBeforeTransfer

Tracks transfer parameters and returns approval


```solidity
function onBeforeTransfer(address token, address from, address to, uint256 amount)
    external
    returns (HookOutput memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`HookOutput`|HookOutput with approved=true and empty message|


### name

Returns the human readable name of this hook


```solidity
function name() external pure returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|Hook name|


### hookId

Returns the unique identifier for this hook


```solidity
function hookId() external pure returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|bytes32 The hook identifier|


### getCallCount

Returns the number of tracked calls


```solidity
function getCallCount() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 The number of calls tracked|


### clearCalls

Clears all tracked calls for test cleanup


```solidity
function clearCalls() external;
```

## Structs
### TrackedCall

```solidity
struct TrackedCall {
    address token;
    address operator;
    Operation operation;
    uint256 assets;
    address receiver;
    address owner;
}
```

## Enums
### Operation

```solidity
enum Operation {
    Deposit,
    Withdraw,
    Transfer
}
```

