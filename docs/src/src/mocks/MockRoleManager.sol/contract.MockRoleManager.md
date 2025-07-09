# MockRoleManager
[Git Source](https://github.com/SovaNetwork/fountfi/blob/58164582109e1a7de75ddd7e30bfe628ac79d7fd/src/mocks/MockRoleManager.sol)

Mock implementation of RoleManager for testing


## State Variables
### PROTOCOL_ADMIN

```solidity
uint256 public constant PROTOCOL_ADMIN = 1 << 0;
```


### REGISTRY_ADMIN

```solidity
uint256 public constant REGISTRY_ADMIN = 1 << 1;
```


### STRATEGY_ADMIN

```solidity
uint256 public constant STRATEGY_ADMIN = 1 << 2;
```


### KYC_ADMIN

```solidity
uint256 public constant KYC_ADMIN = 1 << 3;
```


### REPORTER_ADMIN

```solidity
uint256 public constant REPORTER_ADMIN = 1 << 4;
```


### SUBSCRIPTION_ADMIN

```solidity
uint256 public constant SUBSCRIPTION_ADMIN = 1 << 5;
```


### WITHDRAWAL_ADMIN

```solidity
uint256 public constant WITHDRAWAL_ADMIN = 1 << 6;
```


### STRATEGY_MANAGER

```solidity
uint256 public constant STRATEGY_MANAGER = 1 << 7;
```


### KYC_OPERATOR

```solidity
uint256 public constant KYC_OPERATOR = 1 << 8;
```


### DATA_PROVIDER

```solidity
uint256 public constant DATA_PROVIDER = 1 << 9;
```


### owner

```solidity
address public owner;
```


### roles

```solidity
mapping(address => mapping(uint256 => bool)) public roles;
```


## Functions
### constructor


```solidity
constructor(address _owner);
```

### grantRole


```solidity
function grantRole(address user, uint256 role) external;
```

### revokeRole


```solidity
function revokeRole(address user, uint256 role) external;
```

### hasRole


```solidity
function hasRole(address user, uint256 role) external view returns (bool);
```

### hasAnyRole


```solidity
function hasAnyRole(address user, uint256 role) external view returns (bool);
```

### hasAllRoles


```solidity
function hasAllRoles(address user, uint256 role) external view returns (bool);
```

### hasAnyOfRoles


```solidity
function hasAnyOfRoles(address user, uint256[] calldata _roles) external view returns (bool);
```

### hasAllRolesArray


```solidity
function hasAllRolesArray(address user, uint256[] calldata _roles) external view returns (bool);
```

### renounceRole


```solidity
function renounceRole(uint256 role) external;
```

