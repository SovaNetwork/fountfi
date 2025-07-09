# BasicStrategy
[Git Source](https://github.com/SovaNetwork/fountfi/blob/58164582109e1a7de75ddd7e30bfe628ac79d7fd/src/strategy/BasicStrategy.sol)

**Inherits:**
[IStrategy](/src/strategy/IStrategy.sol/interface.IStrategy.md), [CloneableRoleManaged](/src/auth/CloneableRoleManaged.sol/abstract.CloneableRoleManaged.md)

A basic strategy contract for managing tRWA assets

*Each strategy deploys its own tRWA token (sToken)
Consider for future: Making BasicStrategy an ERC4337-compatible smart account*


## State Variables
### manager
The manager of the strategy


```solidity
address public manager;
```


### asset
The asset of the strategy


```solidity
address public asset;
```


### sToken
The sToken of the strategy


```solidity
address public sToken;
```


### _initialized
Initialization flags to prevent re-initialization


```solidity
bool internal _initialized;
```


## Functions
### initialize

Initialize the strategy


```solidity
function initialize(
    string calldata name_,
    string calldata symbol_,
    address roleManager_,
    address manager_,
    address asset_,
    uint8 assetDecimals_,
    bytes memory
) public virtual override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`name_`|`string`|Name of the token|
|`symbol_`|`string`|Symbol of the token|
|`roleManager_`|`address`|Address of the role manager|
|`manager_`|`address`|Address of the manager|
|`asset_`|`address`|Address of the underlying asset|
|`assetDecimals_`|`uint8`|Decimals of the asset|
|`<none>`|`bytes`||


### _deployToken

Deploy a new tRWA token


```solidity
function _deployToken(string calldata name_, string calldata symbol_, address asset_, uint8 assetDecimals_)
    internal
    virtual
    returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`name_`|`string`|Name of the token|
|`symbol_`|`string`|Symbol of the token|
|`asset_`|`address`|Address of the underlying asset|
|`assetDecimals_`|`uint8`|Decimals of the asset|


### setManager

Allow admin to change the manager


```solidity
function setManager(address newManager) external onlyRoles(roleManager.STRATEGY_ADMIN());
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newManager`|`address`|The new manager|


### balance

Get the balance of the strategy


```solidity
function balance() external view virtual returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The balance of the strategy in the underlying asset|


### sendETH

Send owned ETH to an address


```solidity
function sendETH(address to) external onlyManager;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|The address to send the ETH to|


### sendToken

Send owned ERC20 tokens to an address


```solidity
function sendToken(address tokenAddr, address to, uint256 amount) external onlyManager;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenAddr`|`address`|The address of the ERC20 token to send|
|`to`|`address`|The address to send the tokens to|
|`amount`|`uint256`|The amount of tokens to send|


### pullToken

Pull ERC20 tokens from an external contract into this contract


```solidity
function pullToken(address tokenAddr, address from, uint256 amount) external onlyManager;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenAddr`|`address`|The address of the ERC20 token to pull|
|`from`|`address`|The address to pull the tokens from|
|`amount`|`uint256`|The amount of tokens to pull|


### setAllowance

Set the allowance for an ERC20 token


```solidity
function setAllowance(address tokenAddr, address spender, uint256 amount) external onlyManager;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenAddr`|`address`|The address of the ERC20 token to set the allowance for|
|`spender`|`address`|The address to set the allowance for|
|`amount`|`uint256`|The amount of allowance to set|


### callStrategyToken

Call the strategy token

*Used for configuring token hooks*


```solidity
function callStrategyToken(bytes calldata data) external onlyRoles(roleManager.STRATEGY_ADMIN());
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`data`|`bytes`|The calldata to call the strategy token with|


### call

Execute arbitrary transactions on behalf of the strategy


```solidity
function call(address target, uint256 value, bytes calldata data)
    external
    onlyManager
    returns (bool success, bytes memory returnData);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`target`|`address`|Address of the contract to call|
|`value`|`uint256`|Amount of ETH to send|
|`data`|`bytes`|Calldata to send|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`success`|`bool`|Whether the call succeeded|
|`returnData`|`bytes`|The return data from the call|


### onlyManager


```solidity
modifier onlyManager();
```

### receive


```solidity
receive() external payable;
```

