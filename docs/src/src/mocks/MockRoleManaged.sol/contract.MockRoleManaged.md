# MockRoleManaged
[Git Source](https://github.com/SovaNetwork/fountfi/blob/58164582109e1a7de75ddd7e30bfe628ac79d7fd/src/mocks/MockRoleManaged.sol)

**Inherits:**
[RoleManaged](/src/auth/RoleManaged.sol/abstract.RoleManaged.md)

Mock contract for testing role-based access control


## State Variables
### counter

```solidity
uint256 public counter;
```


## Functions
### constructor


```solidity
constructor(address _roleManager) RoleManaged(_roleManager);
```

### incrementAsProtocolAdmin

Function that can only be called by PROTOCOL_ADMIN


```solidity
function incrementAsProtocolAdmin() external onlyRoles(roleManager.PROTOCOL_ADMIN());
```

### incrementAsRulesAdmin

Function that can only be called by RULES_ADMIN


```solidity
function incrementAsRulesAdmin() external onlyRoles(roleManager.RULES_ADMIN());
```

### incrementAsStrategyRole

Function that can be called by either STRATEGY_ADMIN or STRATEGY_MANAGER


```solidity
function incrementAsStrategyRole() external onlyRoles(_getStrategyRoles());
```

### incrementAsKycAdmin

Function that can be called by KYC_ADMIN


```solidity
function incrementAsKycAdmin() external onlyRoles(roleManager.KYC_OPERATOR());
```

### incrementAsKycOperator

Function that can be called by KYC_OPERATOR


```solidity
function incrementAsKycOperator() external onlyRoles(roleManager.KYC_OPERATOR());
```

### getCounter

Get the current counter value - no restrictions


```solidity
function getCounter() external view returns (uint256);
```

### _getStrategyRoles

Helper function to get the strategy roles


```solidity
function _getStrategyRoles() internal view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|roles Array containing STRATEGY_ADMIN and STRATEGY_MANAGER roles|


## Events
### CounterIncremented

```solidity
event CounterIncremented(address operator, uint256 newValue);
```

