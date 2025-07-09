# Conduit
[Git Source](https://github.com/SovaNetwork/fountfi/blob/58164582109e1a7de75ddd7e30bfe628ac79d7fd/src/conduit/Conduit.sol)

**Inherits:**
[RoleManaged](/src/auth/RoleManaged.sol/abstract.RoleManaged.md)

Contract to collect deposits on behalf of tRWA contracts

*This contract is used to collect deposits from users, and transfer them
to strategy contracts. This allows users to make single global approvals
to the Conduit contract, and then deposit into any strategy.*


## Functions
### constructor

Constructor

*Constructor is called by the registry contract*


```solidity
constructor(address _roleManager) RoleManaged(_roleManager);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_roleManager`|`address`|Address of the role manager contract|


### collectDeposit

Executes a token transfer on behalf of an approved tRWA contract.

*The user (`_from`) must have approved this Conduit contract to spend `_amount` of `_token`.
Only callable by an `approvedTRWAContracts`.*


```solidity
function collectDeposit(address token, address from, address to, uint256 amount) external returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|The address of the ERC20 token to transfer.|
|`from`|`address`|The address of the user whose tokens are being transferred.|
|`to`|`address`|The address to transfer the tokens to (e.g., the tRWA contract or a designated vault).|
|`amount`|`uint256`|The amount of tokens to transfer.|


### rescueERC20

Rescues ERC20 tokens from the conduit


```solidity
function rescueERC20(address tokenAddress, address to, uint256 amount)
    external
    onlyRoles(roleManager.PROTOCOL_ADMIN());
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenAddress`|`address`|The address of the ERC20 token to rescue|
|`to`|`address`|The address to transfer the tokens to|
|`amount`|`uint256`|The amount of tokens to transfer|


## Errors
### InvalidAmount

```solidity
error InvalidAmount();
```

### InvalidToken

```solidity
error InvalidToken();
```

### InvalidDestination

```solidity
error InvalidDestination();
```

