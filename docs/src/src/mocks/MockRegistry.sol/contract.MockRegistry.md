# MockRegistry
[Git Source](https://github.com/SovaNetwork/fountfi/blob/58164582109e1a7de75ddd7e30bfe628ac79d7fd/src/mocks/MockRegistry.sol)

Mock implementation of IRegistry for testing


## State Variables
### allowedAssets

```solidity
mapping(address => uint8) public allowedAssets;
```


### validStrategies

```solidity
mapping(address => bool) public validStrategies;
```


### isStrategyToken

```solidity
mapping(address => bool) public isStrategyToken;
```


### conduit

```solidity
address public conduit;
```


## Functions
### setAsset

Set an asset as allowed


```solidity
function setAsset(address asset, uint8 decimals) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The asset address|
|`decimals`|`uint8`|The asset decimals|


### setStrategyToken

Set a token as strategy token


```solidity
function setStrategyToken(address token, bool value) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|The token address|
|`value`|`bool`|Whether the token is a strategy token|


### setStrategy

Set a strategy as valid


```solidity
function setStrategy(address strategy, bool value) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`strategy`|`address`|The strategy address|
|`value`|`bool`|Whether the strategy is valid|


### setConduit

Set the conduit address


```solidity
function setConduit(address _conduit) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_conduit`|`address`|The conduit address|


