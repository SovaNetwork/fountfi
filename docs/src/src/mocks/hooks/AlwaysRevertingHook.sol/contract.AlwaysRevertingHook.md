# AlwaysRevertingHook
[Git Source](https://github.com/SovaNetwork/fountfi/blob/58164582109e1a7de75ddd7e30bfe628ac79d7fd/src/mocks/hooks/AlwaysRevertingHook.sol)

**Inherits:**
[IHook](/src/hooks/IHook.sol/interface.IHook.md)

Mock hook that always reverts with a custom error message for testing error handling


## State Variables
### revertMessage

```solidity
string public revertMessage;
```


## Functions
### constructor

Constructor to set the revert message


```solidity
constructor(string memory _message);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_message`|`string`|The message to revert with|


### onBeforeDeposit

Always reverts on deposit operations

*This function will never return successfully*


```solidity
function onBeforeDeposit(address, address, uint256, address) external view returns (HookOutput memory);
```

### onBeforeWithdraw

Always reverts on withdraw operations

*This function will never return successfully*


```solidity
function onBeforeWithdraw(address, address, uint256, address, address) external view returns (HookOutput memory);
```

### onBeforeTransfer

Always reverts on transfer operations

*This function will never return successfully*


```solidity
function onBeforeTransfer(address, address, address, uint256) external view returns (HookOutput memory);
```

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


