# MockSubscriptionHook
[Git Source](https://github.com/SovaNetwork/fountfi/blob/58164582109e1a7de75ddd7e30bfe628ac79d7fd/src/mocks/hooks/MockSubscriptionHook.sol)

**Inherits:**
[BaseHook](/src/hooks/BaseHook.sol/abstract.BaseHook.md)

Mock implementation of a subscription hook for testing


## State Variables
### subscriptionsOpen

```solidity
bool public subscriptionsOpen;
```


### enforceApproval

```solidity
bool public enforceApproval;
```


### isSubscriber

```solidity
mapping(address => bool) public isSubscriber;
```


### manager

```solidity
address public manager;
```


## Functions
### constructor

Constructor


```solidity
constructor(address _manager, bool _enforceApproval, bool _subscriptionsOpen) BaseHook("MockSubscriptionHook");
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_manager`|`address`|Address of the manager|
|`_enforceApproval`|`bool`|Whether to enforce approval|
|`_subscriptionsOpen`|`bool`|Whether subscriptions are open|


### setSubscriber

Set subscriber status


```solidity
function setSubscriber(address subscriber, bool status) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`subscriber`|`address`|Address of the subscriber|
|`status`|`bool`|Whether the subscriber is approved|


### setSubscriptionStatus

Set subscription status


```solidity
function setSubscriptionStatus(bool open) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`open`|`bool`|Whether subscriptions are open|


### setEnforceApproval

Set whether to enforce approval


```solidity
function setEnforceApproval(bool enforce) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`enforce`|`bool`|Whether to enforce approval|


### batchSetSubscribers

Batch set subscriber statuses


```solidity
function batchSetSubscribers(address[] calldata subscribers, bool status) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`subscribers`|`address[]`|Array of subscriber addresses|
|`status`|`bool`|Whether the subscribers are approved|


### onBeforeDeposit

Hook called before deposit


```solidity
function onBeforeDeposit(address, address, uint256, address receiver)
    public
    view
    override
    returns (IHook.HookOutput memory output);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`||
|`<none>`|`address`||
|`<none>`|`uint256`||
|`receiver`|`address`|Address of the receiver|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`output`|`IHook.HookOutput`|Hook output|


## Events
### SubscriberStatusChanged

```solidity
event SubscriberStatusChanged(address indexed subscriber, bool indexed approved);
```

### SubscriptionStatusChanged

```solidity
event SubscriptionStatusChanged(bool indexed open);
```

### ApprovalEnforcementChanged

```solidity
event ApprovalEnforcementChanged(bool indexed enforced);
```

### BatchSubscribersChanged

```solidity
event BatchSubscribersChanged(uint256 count, bool status);
```

## Errors
### Unauthorized

```solidity
error Unauthorized();
```

### InvalidArrayLength

```solidity
error InvalidArrayLength();
```

