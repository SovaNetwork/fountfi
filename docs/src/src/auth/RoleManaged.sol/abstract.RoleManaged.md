# RoleManaged
[Git Source](https://github.com/SovaNetwork/fountfi/blob/58164582109e1a7de75ddd7e30bfe628ac79d7fd/src/auth/RoleManaged.sol)

**Inherits:**
[LibRoleManaged](/src/auth/LibRoleManaged.sol/abstract.LibRoleManaged.md)

Base contract for role-managed contracts in the Fountfi protocol

*Provides role checking functionality for contracts*


## Functions
### constructor

Constructor


```solidity
constructor(address _roleManager);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_roleManager`|`address`|Address of the role manager contract|


## Errors
### InvalidRoleManager

```solidity
error InvalidRoleManager();
```

