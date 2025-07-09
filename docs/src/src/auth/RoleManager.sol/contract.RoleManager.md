# RoleManager
[Git Source](https://github.com/SovaNetwork/fountfi/blob/58164582109e1a7de75ddd7e30bfe628ac79d7fd/src/auth/RoleManager.sol)

**Inherits:**
OwnableRoles, [IRoleManager](/src/auth/IRoleManager.sol/interface.IRoleManager.md)

Central role management contract for the Fountfi protocol

*Uses hierarchical bitmasks for core roles. Owner/PROTOCOL_ADMIN have override.*


## State Variables
### PROTOCOL_ADMIN

```solidity
uint256 public constant PROTOCOL_ADMIN = 1 << 1;
```


### STRATEGY_ADMIN

```solidity
uint256 public constant STRATEGY_ADMIN = 1 << 2;
```


### RULES_ADMIN

```solidity
uint256 public constant RULES_ADMIN = 1 << 3;
```


### STRATEGY_OPERATOR

```solidity
uint256 public constant STRATEGY_OPERATOR = 1 << 4;
```


### KYC_OPERATOR

```solidity
uint256 public constant KYC_OPERATOR = 1 << 5;
```


### roleAdminRole
Mapping from a target role to the specific (admin) role required to manage it.

*If a role maps to 0, only owner or PROTOCOL_ADMIN can manage it.*


```solidity
mapping(uint256 => uint256) public roleAdminRole;
```


### registry
The address of the registry contract, used as global reference


```solidity
address public registry;
```


## Functions
### constructor

Constructor that sets up the initial roles

*Initializes the owner and grants all roles to the deployer*


```solidity
constructor();
```

### initializeRegistry

Initialize the role manager with the registry contract


```solidity
function initializeRegistry(address _registry) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_registry`|`address`|The address of the registry|


### grantRole

Grants a role to a user


```solidity
function grantRole(address user, uint256 role) public virtual override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address of the user to grant the role to|
|`role`|`uint256`|The role to grant|


### revokeRole

Revokes a role from a user


```solidity
function revokeRole(address user, uint256 role) public virtual override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address of the user to revoke the role from|
|`role`|`uint256`|The role to revoke|


### setRoleAdmin

Sets the specific role required to manage a target role

*Requires the caller to have the PROTOCOL_ADMIN role or be the owner*


```solidity
function setRoleAdmin(uint256 targetRole, uint256 adminRole) external virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`targetRole`|`uint256`|The role whose admin role is to be set|
|`adminRole`|`uint256`|The role that will be required to manage the targetRole|


### _canManageRole

Internal function to check if an address can manage a specific role

*Leverages hierarchical bitmasks. Manager must possess all target role bits plus additional bits.*


```solidity
function _canManageRole(address manager, uint256 role) internal view virtual returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`manager`|`address`|The address to check for management permission|
|`role`|`uint256`|The role being managed|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the manager can grant/revoke the role|


### _setInitialAdminRole

Internal helper to set initial admin roles during construction

*Does not perform authorization checks.*


```solidity
function _setInitialAdminRole(uint256 targetRole, uint256 adminRole) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`targetRole`|`uint256`|The role whose admin role is to be set|
|`adminRole`|`uint256`|The role that will be required to manage the targetRole|


