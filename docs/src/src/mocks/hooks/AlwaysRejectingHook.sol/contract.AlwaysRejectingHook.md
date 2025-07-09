# AlwaysRejectingHook
[Git Source](https://github.com/SovaNetwork/fountfi/blob/58164582109e1a7de75ddd7e30bfe628ac79d7fd/src/mocks/hooks/AlwaysRejectingHook.sol)

**Inherits:**
[IHook](/src/hooks/IHook.sol/interface.IHook.md)

Mock hook that always rejects all operations with a custom message for testing


## State Variables
### rejectMessage

```solidity
string public rejectMessage;
```


## Functions
### constructor

Constructor to set the rejection message


```solidity
constructor(string memory _message);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_message`|`string`|The message to return when rejecting operations|


### onBeforeDeposit

Always rejects deposit operations


```solidity
function onBeforeDeposit(address, address, uint256, address) external view returns (HookOutput memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`HookOutput`|HookOutput with approved=false and the rejection message|


### onBeforeWithdraw

Always rejects withdraw operations


```solidity
function onBeforeWithdraw(address, address, uint256, address, address) external view returns (HookOutput memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`HookOutput`|HookOutput with approved=false and the rejection message|


### onBeforeTransfer

Always rejects transfer operations


```solidity
function onBeforeTransfer(address, address, address, uint256) external view returns (HookOutput memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`HookOutput`|HookOutput with approved=false and the rejection message|


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


