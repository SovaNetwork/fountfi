# BaseHook
[Git Source](https://github.com/SovaNetwork/fountfi/blob/58164582109e1a7de75ddd7e30bfe628ac79d7fd/src/hooks/BaseHook.sol)

**Inherits:**
[IHook](/src/hooks/IHook.sol/interface.IHook.md)

NOTE: For future stateful hooks, consider access control on the hook functions.

Base contract for all hooks

*This contract is used to implement the IHook interface
and provides a base implementation for all hooks.
It is not meant to be used as a standalone contract.*


## State Variables
### name
Human readable name of the hook


```solidity
string public override name;
```


## Functions
### constructor

Constructor


```solidity
constructor(string memory _name);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_name`|`string`|Human readable name of the hook|


### hookId

Returns the unique identifier for this hook


```solidity
function hookId() external view override returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|Hook identifier|


### onBeforeDeposit

Called before a deposit operation


```solidity
function onBeforeDeposit(address, address, uint256, address)
    public
    virtual
    override
    returns (IHook.HookOutput memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IHook.HookOutput`|HookOutput Result of the hook evaluation|


### onBeforeWithdraw

Called before a withdraw operation


```solidity
function onBeforeWithdraw(address, address, uint256, address, address)
    public
    virtual
    override
    returns (IHook.HookOutput memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IHook.HookOutput`|HookOutput Result of the hook evaluation|


### onBeforeTransfer

Called before a transfer operation


```solidity
function onBeforeTransfer(address, address, address, uint256)
    public
    virtual
    override
    returns (IHook.HookOutput memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IHook.HookOutput`|HookOutput Result of the hook evaluation|


