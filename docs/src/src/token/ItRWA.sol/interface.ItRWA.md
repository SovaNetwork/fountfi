# ItRWA
[Git Source](https://github.com/SovaNetwork/fountfi/blob/58164582109e1a7de75ddd7e30bfe628ac79d7fd/src/token/ItRWA.sol)

Interface for Tokenized Real World Asset (tRWA)

*Defines the interface with all events and errors for the tRWA contract
This is an extension interface (does not duplicate ERC4626 methods)*


## Functions
### strategy

Returns the address of the strategy


```solidity
function strategy() external view returns (address);
```

### asset

Returns the address of the underlying asset


```solidity
function asset() external view returns (address);
```

## Errors
### InvalidAddress

```solidity
error InvalidAddress();
```

### AssetMismatch

```solidity
error AssetMismatch();
```

### RuleCheckFailed

```solidity
error RuleCheckFailed(string reason);
```

