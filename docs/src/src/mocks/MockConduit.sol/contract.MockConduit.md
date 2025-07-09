# MockConduit
[Git Source](https://github.com/SovaNetwork/fountfi/blob/58164582109e1a7de75ddd7e30bfe628ac79d7fd/src/mocks/MockConduit.sol)

Simple mock implementation of conduit for testing


## Functions
### collectDeposit

Simulates collecting deposits, just transfers tokens directly


```solidity
function collectDeposit(address token, address from, address to, uint256 amount) external returns (bool);
```

