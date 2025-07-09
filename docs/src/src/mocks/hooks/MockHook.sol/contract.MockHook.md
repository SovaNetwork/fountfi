# MockHook
[Git Source](https://github.com/SovaNetwork/fountfi/blob/58164582109e1a7de75ddd7e30bfe628ac79d7fd/src/mocks/hooks/MockHook.sol)

**Inherits:**
[IHook](/src/hooks/IHook.sol/interface.IHook.md)

Mock implementation of the IHook interface for testing


## State Variables
### name

```solidity
string public name;
```


### approveOperations

```solidity
bool public approveOperations;
```


### rejectReason

```solidity
string public rejectReason;
```


## Functions
### constructor


```solidity
constructor(bool _approveOperations, string memory _rejectReason);
```

### setName

Set the name of the hook (useful for creating unique identifiers in tests)


```solidity
function setName(string memory _name) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_name`|`string`|New name for the hook|


### setApproveStatus

Set whether operations should be approved


```solidity
function setApproveStatus(bool _approve, string memory _reason) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_approve`|`bool`|Whether operations should be approved|
|`_reason`|`string`|Reason for rejection if not approved|


### hookId

Returns the unique identifier for this hook


```solidity
function hookId() external view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|Hook identifier|


### hookName

Returns the human readable name of this hook


```solidity
function hookName() external view returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|Hook name|


### onBeforeDeposit

Called before a deposit operation


```solidity
function onBeforeDeposit(address token, address user, uint256 assets, address receiver)
    external
    virtual
    returns (HookOutput memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Address of the token|
|`user`|`address`|Address of the user|
|`assets`|`uint256`|Amount of assets to deposit|
|`receiver`|`address`|Address of the receiver|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`HookOutput`|result Result of the hook evaluation|


### onBeforeWithdraw

Called before a withdraw operation


```solidity
function onBeforeWithdraw(address token, address by, uint256 assets, address to, address owner)
    external
    virtual
    returns (HookOutput memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Address of the token|
|`by`|`address`|Address of the sender|
|`assets`|`uint256`|Amount of assets to withdraw|
|`to`|`address`|Address of the receiver|
|`owner`|`address`|Address of the owner|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`HookOutput`|result Result of the hook evaluation|


### onBeforeTransfer

Called before a transfer operation


```solidity
function onBeforeTransfer(address token, address from, address to, uint256 amount)
    external
    virtual
    returns (HookOutput memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Address of the token|
|`from`|`address`|Address of the sender|
|`to`|`address`|Address of the receiver|
|`amount`|`uint256`|Amount of assets to transfer|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`HookOutput`|result Result of the hook evaluation|


## Events
### HookCalled

```solidity
event HookCalled(string operation, address token, address user, uint256 assets, address receiver);
```

### WithdrawHookCalled

```solidity
event WithdrawHookCalled(address token, address by, uint256 assets, address to, address owner);
```

### TransferHookCalled

```solidity
event TransferHookCalled(address token, address from, address to, uint256 amount);
```

