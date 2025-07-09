# IHook
[Git Source](https://github.com/SovaNetwork/fountfi/blob/58164582109e1a7de75ddd7e30bfe628ac79d7fd/src/hooks/IHook.sol)

Interface for operation hooks in the tRWA system

*Operation hooks are called before key operations (deposit, withdraw, transfer)
and can approve or reject the operation with a reason*


## Functions
### hookId

Returns the unique identifier for this hook


```solidity
function hookId() external view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|Hook identifier|


### name

Returns the human readable name of this hook


```solidity
function name() external view returns (string memory);
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
|`<none>`|`HookOutput`|HookOutput Result of the hook evaluation|


### onBeforeWithdraw

Called before a withdraw operation


```solidity
function onBeforeWithdraw(address token, address by, uint256 assets, address to, address owner)
    external
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
|`<none>`|`HookOutput`|HookOutput Result of the hook evaluation|


### onBeforeTransfer

Called before a transfer operation


```solidity
function onBeforeTransfer(address token, address from, address to, uint256 amount)
    external
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
|`<none>`|`HookOutput`|HookOutput Result of the hook evaluation|


## Structs
### HookOutput
Structure representing the result of a hook evaluation


```solidity
struct HookOutput {
    bool approved;
    string reason;
}
```

**Properties**

|Name|Type|Description|
|----|----|-----------|
|`approved`|`bool`|Whether the operation is approved by this hook|
|`reason`|`string`|Reason for approval/rejection (for logging or error messages)|

