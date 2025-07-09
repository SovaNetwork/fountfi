# KycRulesHook
[Git Source](https://github.com/SovaNetwork/fountfi/blob/58164582109e1a7de75ddd7e30bfe628ac79d7fd/src/hooks/KycRulesHook.sol)

**Inherits:**
[BaseHook](/src/hooks/BaseHook.sol/abstract.BaseHook.md), [RoleManaged](/src/auth/RoleManaged.sol/abstract.RoleManaged.md)

Hook that restricts transfers based on sender/receiver KYC status

*Uses allow/deny lists to determine if transfers are permitted*


## State Variables
### isAddressAllowed

```solidity
mapping(address => bool) public isAddressAllowed;
```


### isAddressDenied

```solidity
mapping(address => bool) public isAddressDenied;
```


## Functions
### constructor

Constructor


```solidity
constructor(address _roleManager) BaseHook("KycRulesHook-1.0") RoleManaged(_roleManager);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_roleManager`|`address`|Address of the role manager contract|


### allow

Allow an address to transfer/receive tokens


```solidity
function allow(address account) external onlyRoles(roleManager.KYC_OPERATOR());
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Address to allow|


### deny

Deny an address from transferring/receiving tokens


```solidity
function deny(address account) external onlyRoles(roleManager.KYC_OPERATOR());
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Address to deny|


### reset

Reset an address by removing it from both allow and deny lists


```solidity
function reset(address account) external onlyRoles(roleManager.KYC_OPERATOR());
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Address to reset|


### batchAllow

Batch allow addresses to transfer/receive tokens


```solidity
function batchAllow(address[] calldata accounts) external onlyRoles(roleManager.KYC_OPERATOR());
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`accounts`|`address[]`|Array of addresses to allow|


### batchDeny

Batch deny addresses from transferring/receiving tokens


```solidity
function batchDeny(address[] calldata accounts) external onlyRoles(roleManager.KYC_OPERATOR());
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`accounts`|`address[]`|Array of addresses to deny|


### batchReset

Batch reset addresses by removing them from both allow and deny lists


```solidity
function batchReset(address[] calldata accounts) external onlyRoles(roleManager.KYC_OPERATOR());
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`accounts`|`address[]`|Array of addresses to reset|


### isAllowed

Check if an address is allowed to transfer/receive tokens


```solidity
function isAllowed(address account) public view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Address to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the address is allowed|


### _allow

Internal function to allow an address


```solidity
function _allow(address account) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Address to allow|


### _deny

Internal function to deny an address


```solidity
function _deny(address account) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Address to deny|


### _reset

Internal function to reset an address


```solidity
function _reset(address account) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Address to reset|


### onBeforeTransfer

Hook executed before a transfer operation


```solidity
function onBeforeTransfer(address, address from, address to, uint256)
    public
    view
    override
    returns (IHook.HookOutput memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`||
|`from`|`address`|Address sending tokens|
|`to`|`address`|Address receiving tokens|
|`<none>`|`uint256`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IHook.HookOutput`|bytes4 Selector indicating success or specific failure reason|


### onBeforeDeposit

Hook executed before a deposit operation


```solidity
function onBeforeDeposit(address, address user, uint256, address receiver)
    public
    view
    override
    returns (IHook.HookOutput memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`||
|`user`|`address`|Address initiating the deposit|
|`<none>`|`uint256`||
|`receiver`|`address`|Address receiving the shares|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IHook.HookOutput`|bytes4 Selector indicating success or specific failure reason|


### onBeforeWithdraw

Hook executed before a withdraw operation


```solidity
function onBeforeWithdraw(address, address user, uint256, address receiver, address owner)
    public
    view
    override
    returns (IHook.HookOutput memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`||
|`user`|`address`|Address initiating the withdrawal|
|`<none>`|`uint256`||
|`receiver`|`address`|Address receiving the assets|
|`owner`|`address`|Address owning the shares|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IHook.HookOutput`|bytes4 Selector indicating success or specific failure reason|


### _checkSenderAndReceiver

Internal function to check if both sender and receiver are allowed


```solidity
function _checkSenderAndReceiver(address from, address to) internal view returns (IHook.HookOutput memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|Address sending tokens|
|`to`|`address`|Address receiving tokens|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IHook.HookOutput`|IHook.HookOutput Result of the check|


## Events
### AddressAllowed

```solidity
event AddressAllowed(address indexed account, address indexed operator);
```

### AddressDenied

```solidity
event AddressDenied(address indexed account, address indexed operator);
```

### AddressRestrictionRemoved

```solidity
event AddressRestrictionRemoved(address indexed account, address indexed operator);
```

### BatchAddressAllowed

```solidity
event BatchAddressAllowed(uint256 count, address indexed operator);
```

### BatchAddressDenied

```solidity
event BatchAddressDenied(uint256 count, address indexed operator);
```

### BatchAddressRestrictionRemoved

```solidity
event BatchAddressRestrictionRemoved(uint256 count, address indexed operator);
```

## Errors
### ZeroAddress

```solidity
error ZeroAddress();
```

### AddressAlreadyDenied

```solidity
error AddressAlreadyDenied();
```

### InvalidArrayLength

```solidity
error InvalidArrayLength();
```

