# ManagedWithdrawReportedStrategy
[Git Source](https://github.com/SovaNetwork/fountfi/blob/58164582109e1a7de75ddd7e30bfe628ac79d7fd/src/strategy/ManagedWithdrawRWAStrategy.sol)

**Inherits:**
[ReportedStrategy](/src/strategy/ReportedStrategy.sol/contract.ReportedStrategy.md)

Extension of ReportedStrategy that deploys and configures ManagedWithdrawRWA tokens


## State Variables
### EIP712_DOMAIN_TYPEHASH

```solidity
bytes32 private constant EIP712_DOMAIN_TYPEHASH =
    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
```


### WITHDRAWAL_REQUEST_TYPEHASH

```solidity
bytes32 private constant WITHDRAWAL_REQUEST_TYPEHASH = keccak256(
    "WithdrawalRequest(address owner,address to,uint256 shares,uint256 minAssets,uint96 nonce,uint96 expirationTime)"
);
```


### usedNonces

```solidity
mapping(address => mapping(uint96 => bool)) public usedNonces;
```


## Functions
### initialize

Initialize the strategy with ManagedWithdrawRWA token


```solidity
function initialize(
    string calldata name_,
    string calldata symbol_,
    address roleManager_,
    address manager_,
    address asset_,
    uint8 assetDecimals_,
    bytes memory initData
) public override;
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
|`initData`|`bytes`|Additional initialization data (unused)|


### _deployToken

Deploy a new ManagedWithdrawRWA token


```solidity
function _deployToken(string calldata name_, string calldata symbol_, address asset_, uint8 assetDecimals_)
    internal
    virtual
    override
    returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`name_`|`string`|Name of the token|
|`symbol_`|`string`|Symbol of the token|
|`asset_`|`address`|Address of the underlying asset|
|`assetDecimals_`|`uint8`|Decimals of the asset|


### redeem

Process a user-requested withdrawal


```solidity
function redeem(WithdrawalRequest calldata request, Signature calldata userSig)
    external
    onlyManager
    returns (uint256 assets);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`request`|`WithdrawalRequest`|The withdrawal request|
|`userSig`|`Signature`|The signature of the request|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`|The amount of assets received|


### batchRedeem

Process a batch of user-requested withdrawals


```solidity
function batchRedeem(WithdrawalRequest[] calldata requests, Signature[] calldata signatures)
    external
    onlyManager
    returns (uint256[] memory assets);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`requests`|`WithdrawalRequest[]`|The withdrawal requests|
|`signatures`|`Signature[]`|The signatures of the requests|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256[]`|The amount of assets received|


### _validateRedeem

Validate a withdrawal request's arguments and consume the nonce


```solidity
function _validateRedeem(WithdrawalRequest calldata request) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`request`|`WithdrawalRequest`|The withdrawal request|


### _verifySignature

Verify a signature using EIP-712


```solidity
function _verifySignature(WithdrawalRequest calldata request, Signature calldata signature) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`request`|`WithdrawalRequest`|The withdrawal request|
|`signature`|`Signature`|The signature|


### _domainSeparator

Calculate the EIP-712 domain separator


```solidity
function _domainSeparator() internal view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The domain separator|


## Events
### WithdrawalNonceUsed

```solidity
event WithdrawalNonceUsed(address indexed owner, uint96 nonce);
```

## Errors
### WithdrawalRequestExpired

```solidity
error WithdrawalRequestExpired();
```

### WithdrawNonceReuse

```solidity
error WithdrawNonceReuse();
```

### WithdrawInvalidSignature

```solidity
error WithdrawInvalidSignature();
```

### InvalidArrayLengths

```solidity
error InvalidArrayLengths();
```

## Structs
### Signature
Signature argument struct


```solidity
struct Signature {
    uint8 v;
    bytes32 r;
    bytes32 s;
}
```

### WithdrawalRequest
Struct to track withdrawal requests


```solidity
struct WithdrawalRequest {
    uint256 shares;
    uint256 minAssets;
    address owner;
    uint96 nonce;
    address to;
    uint96 expirationTime;
}
```

