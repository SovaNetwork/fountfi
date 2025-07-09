# RulesEngine
[Git Source](https://github.com/SovaNetwork/fountfi/blob/58164582109e1a7de75ddd7e30bfe628ac79d7fd/src/hooks/RulesEngine.sol)

**Inherits:**
[BaseHook](/src/hooks/BaseHook.sol/abstract.BaseHook.md), [RoleManaged](/src/auth/RoleManaged.sol/abstract.RoleManaged.md)

Implementation of a hook that manages and evaluates a collection of sub-hooks

*Manages a collection of hooks that determine if operations are allowed*


## State Variables
### _hooks
All hooks by ID


```solidity
mapping(bytes32 => HookInfo) private _hooks;
```


### _hookIds
All hook IDs


```solidity
bytes32[] private _hookIds;
```


## Functions
### constructor

Constructor


```solidity
constructor(address _roleManager) BaseHook("RulesEngine-1.0") RoleManaged(_roleManager);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_roleManager`|`address`|Address of the role manager|


### addHook

Add a new hook to the engine


```solidity
function addHook(address hookAddress, uint256 priority)
    external
    onlyRoles(roleManager.RULES_ADMIN())
    returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hookAddress`|`address`|Address of the hook contract implementing IHook|
|`priority`|`uint256`|Priority of the hook (lower numbers execute first)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|hookId Identifier of the added hook|


### removeHook

Remove a hook from the engine


```solidity
function removeHook(bytes32 hookId) external onlyRoles(roleManager.RULES_ADMIN());
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hookId`|`bytes32`|Identifier of the hook to remove|


### changeHookPriority

Change the priority of a hook


```solidity
function changeHookPriority(bytes32 hookId, uint256 newPriority) external onlyRoles(roleManager.RULES_ADMIN());
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hookId`|`bytes32`|Identifier of the hook|
|`newPriority`|`uint256`|New priority for the hook|


### enableHook

Enable a hook


```solidity
function enableHook(bytes32 hookId) external onlyRoles(roleManager.RULES_ADMIN());
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hookId`|`bytes32`|Identifier of the hook to enable|


### disableHook

Disable a hook


```solidity
function disableHook(bytes32 hookId) external onlyRoles(roleManager.RULES_ADMIN());
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hookId`|`bytes32`|Identifier of the hook to disable|


### isHookActive

Check if a hook is active


```solidity
function isHookActive(bytes32 hookId) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hookId`|`bytes32`|Identifier of the hook|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the hook is active|


### getAllHookIds

Get all registered hook identifiers


```solidity
function getAllHookIds() external view returns (bytes32[] memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32[]`|Array of hook identifiers|


### getAllActiveHookIdsSorted

Get all active hook identifiers, sorted by priority


```solidity
function getAllActiveHookIdsSorted() public view returns (bytes32[] memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32[]`|Array of hook identifiers|


### getHookAddress

Get hook address by ID


```solidity
function getHookAddress(bytes32 hookId) external view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hookId`|`bytes32`|Identifier of the hook|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Hook contract address|


### getHookPriority

Get hook priority


```solidity
function getHookPriority(bytes32 hookId) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hookId`|`bytes32`|Identifier of the hook|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Priority value|


### onBeforeTransfer

Evaluate transfer operation against registered hooks


```solidity
function onBeforeTransfer(address token, address from, address to, uint256 amount)
    public
    override
    returns (HookOutput memory);
```

### onBeforeDeposit

Evaluate deposit operation against registered hooks


```solidity
function onBeforeDeposit(address token, address user, uint256 assets, address receiver)
    public
    override
    returns (HookOutput memory);
```

### onBeforeWithdraw

Evaluate withdraw operation against registered hooks


```solidity
function onBeforeWithdraw(address token, address user, uint256 assets, address receiver, address owner)
    public
    override
    returns (HookOutput memory);
```

### _evaluateSubHooks

Internal method to evaluate an operation against all applicable sub-hooks


```solidity
function _evaluateSubHooks(bytes memory callData) internal returns (IHook.HookOutput memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`callData`|`bytes`|Encoded call data for the hook evaluation function (e.g., onBeforeTransfer)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IHook.HookOutput`|resultSelector Bytes4 selector indicating success or failure reason|


### _getSortedActiveHookIds

Get active hook IDs sorted by priority (lower goes first)


```solidity
function _getSortedActiveHookIds() private view returns (bytes32[] memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32[]`|Sorted array of active hook IDs|


## Events
### HookAdded

```solidity
event HookAdded(bytes32 indexed hookId, address indexed hookAddress, uint256 priority);
```

### HookRemoved

```solidity
event HookRemoved(bytes32 indexed hookId);
```

### HookPriorityChanged

```solidity
event HookPriorityChanged(bytes32 indexed hookId, uint256 newPriority);
```

### HookEnabled

```solidity
event HookEnabled(bytes32 indexed hookId);
```

### HookDisabled

```solidity
event HookDisabled(bytes32 indexed hookId);
```

## Errors
### InvalidHookAddress

```solidity
error InvalidHookAddress();
```

### HookAlreadyExists

```solidity
error HookAlreadyExists(bytes32 hookId);
```

### HookNotFound

```solidity
error HookNotFound(bytes32 hookId);
```

### HookEvaluationFailed

```solidity
error HookEvaluationFailed(bytes32 hookId, bytes4 reasonSelector);
```

## Structs
### HookInfo
Hook information


```solidity
struct HookInfo {
    address hookAddress;
    uint256 priority;
    bool active;
}
```

