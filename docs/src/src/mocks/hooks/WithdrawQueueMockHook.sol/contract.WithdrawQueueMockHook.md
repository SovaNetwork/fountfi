# WithdrawQueueMockHook
[Git Source](https://github.com/SovaNetwork/fountfi/blob/58164582109e1a7de75ddd7e30bfe628ac79d7fd/src/mocks/hooks/WithdrawQueueMockHook.sol)

**Inherits:**
[MockHook](/src/mocks/hooks/MockHook.sol/contract.MockHook.md)

Mock hook that enables control over withdrawal responses for queue testing


## State Variables
### withdrawalsQueued

```solidity
bool public withdrawalsQueued = false;
```


## Functions
### constructor


```solidity
constructor(bool initialApprove, string memory rejectReason) MockHook(initialApprove, rejectReason);
```

### setWithdrawalsQueued


```solidity
function setWithdrawalsQueued(bool queued) external;
```

### onBeforeWithdraw


```solidity
function onBeforeWithdraw(address token, address by, uint256 assets, address to, address owner)
    public
    override
    returns (IHook.HookOutput memory);
```

