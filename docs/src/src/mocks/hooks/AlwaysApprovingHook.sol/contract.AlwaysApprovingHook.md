# AlwaysApprovingHook
[Git Source](https://github.com/SovaNetwork/fountfi/blob/58164582109e1a7de75ddd7e30bfe628ac79d7fd/src/mocks/hooks/AlwaysApprovingHook.sol)

**Inherits:**
[IHook](/src/hooks/IHook.sol/interface.IHook.md)

Mock hook that always approves all operations for testing


## Functions
### onBeforeDeposit

Always approves deposit operations


```solidity
function onBeforeDeposit(address, address, uint256, address) external pure returns (HookOutput memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`HookOutput`|HookOutput with approved=true and empty message|


### onBeforeWithdraw

Always approves withdraw operations


```solidity
function onBeforeWithdraw(address, address, uint256, address, address) external pure returns (HookOutput memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`HookOutput`|HookOutput with approved=true and empty message|


### onBeforeTransfer

Always approves transfer operations


```solidity
function onBeforeTransfer(address, address, address, uint256) external pure returns (HookOutput memory);
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


