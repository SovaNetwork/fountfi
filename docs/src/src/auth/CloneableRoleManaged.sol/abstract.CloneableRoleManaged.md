# CloneableRoleManaged
[Git Source](https://github.com/SovaNetwork/fountfi/blob/58164582109e1a7de75ddd7e30bfe628ac79d7fd/src/auth/CloneableRoleManaged.sol)

**Inherits:**
[LibRoleManaged](/src/auth/LibRoleManaged.sol/abstract.LibRoleManaged.md)

Clone-compatible base contract for role-managed contracts in the Fountfi protocol

*Provides role checking functionality for contracts that will be deployed as clones*


## Functions
### _initializeRoleManager

Initialize the role manager (for use with clones)


```solidity
function _initializeRoleManager(address _roleManager) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_roleManager`|`address`|Address of the role manager contract|


## Events
### RoleManagerInitialized

```solidity
event RoleManagerInitialized(address indexed roleManager);
```

## Errors
### InvalidRoleManager

```solidity
error InvalidRoleManager();
```

