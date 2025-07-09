# MockCappedSubscriptionHook
[Git Source](https://github.com/SovaNetwork/fountfi/blob/58164582109e1a7de75ddd7e30bfe628ac79d7fd/src/mocks/hooks/MockCappedSubscriptionHook.sol)

**Inherits:**
[MockHook](/src/mocks/hooks/MockHook.sol/contract.MockHook.md)

Mock hook that implements subscription caps


## State Variables
### maxSubscriptionSize

```solidity
uint256 public maxSubscriptionSize;
```


### subscriptions

```solidity
mapping(address => uint256) public subscriptions;
```


### totalSubscriptions

```solidity
uint256 public totalSubscriptions;
```


## Functions
### constructor


```solidity
constructor(uint256 _maxSubscriptionSize, bool initialApprove, string memory rejectReason)
    MockHook(initialApprove, rejectReason);
```

### setMaxSubscriptionSize


```solidity
function setMaxSubscriptionSize(uint256 _maxSubscriptionSize) external;
```

### onBeforeDeposit


```solidity
function onBeforeDeposit(address token, address user, uint256 assets, address receiver)
    public
    override
    returns (IHook.HookOutput memory);
```

### onBeforeWithdraw


```solidity
function onBeforeWithdraw(address token, address by, uint256 assets, address to, address owner)
    public
    override
    returns (IHook.HookOutput memory);
```

