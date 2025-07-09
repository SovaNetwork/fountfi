# IRoleManager
[Git Source](https://github.com/SovaNetwork/fountfi/blob/58164582109e1a7de75ddd7e30bfe628ac79d7fd/src/auth/IRoleManager.sol)

Interface for the RoleManager contract


## Functions
### grantRole

Grants a role to a user


```solidity
function grantRole(address user, uint256 role) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address of the user to grant the role to|
|`role`|`uint256`|The role to grant|


### revokeRole

Revokes a role from a user


```solidity
function revokeRole(address user, uint256 role) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address of the user to revoke the role from|
|`role`|`uint256`|The role to revoke|


### setRoleAdmin

Sets the specific role required to manage a target role.

*Requires the caller to have the PROTOCOL_ADMIN role or be the owner.*


```solidity
function setRoleAdmin(uint256 targetRole, uint256 adminRole) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`targetRole`|`uint256`|The role whose admin role is to be set. Cannot be PROTOCOL_ADMIN.|
|`adminRole`|`uint256`|The role that will be required to manage the targetRole. Set to 0 to require owner/PROTOCOL_ADMIN.|


## Events
### RoleGranted
Emitted when a role is granted to a user


```solidity
event RoleGranted(address indexed user, uint256 indexed role, address indexed sender);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address of the user|
|`role`|`uint256`|The role that was granted|
|`sender`|`address`|The address that granted the role|

### RoleRevoked
Emitted when a role is revoked from a user


```solidity
event RoleRevoked(address indexed user, uint256 indexed role, address indexed sender);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address of the user|
|`role`|`uint256`|The role that was revoked|
|`sender`|`address`|The address that revoked the role|

### RoleAdminSet
Emitted when the admin role for a target role is updated.


```solidity
event RoleAdminSet(uint256 indexed targetRole, uint256 indexed adminRole, address indexed sender);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`targetRole`|`uint256`|The role whose admin is being changed.|
|`adminRole`|`uint256`|The new role required to manage the targetRole (0 means revert to owner/PROTOCOL_ADMIN).|
|`sender`|`address`|The address that performed the change.|

## Errors
### InvalidRole
Emitted for 0 role in arguments


```solidity
error InvalidRole();
```

### ZeroAddress
Emitted for 0 address in arguments


```solidity
error ZeroAddress();
```

