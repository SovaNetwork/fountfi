# GatedMintEscrow
[Git Source](https://github.com/SovaNetwork/fountfi/blob/58164582109e1a7de75ddd7e30bfe628ac79d7fd/src/strategy/GatedMintEscrow.sol)

Contract to hold assets during the two-phase deposit process

*Deployed alongside each GatedMintRWA token to manage pending deposits*


## State Variables
### token
The GatedMintRWA token address


```solidity
address public immutable token;
```


### asset
The underlying asset address


```solidity
address public immutable asset;
```


### strategy
The strategy contract address


```solidity
address public immutable strategy;
```


### pendingDeposits
Storage for deposits


```solidity
mapping(bytes32 => PendingDeposit) public pendingDeposits;
```


### totalPendingAssets
Accounting for total amounts


```solidity
uint256 public totalPendingAssets;
```


### userPendingAssets
Accounting for user pending assets


```solidity
mapping(address => uint256) public userPendingAssets;
```


### currentRound
Tracking of batch acceptances


```solidity
uint96 public currentRound;
```


## Functions
### constructor

Constructor


```solidity
constructor(address _token, address _asset, address _strategy);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_token`|`address`|The GatedMintRWA token address|
|`_asset`|`address`|The underlying asset address|
|`_strategy`|`address`|The strategy contract address|


### handleDepositReceived

Receive a deposit from the GatedMintRWA token


```solidity
function handleDepositReceived(
    bytes32 depositId,
    address depositor,
    address recipient,
    uint256 amount,
    uint256 expirationTime
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`depositId`|`bytes32`|Unique identifier for the deposit|
|`depositor`|`address`|Address that initiated the deposit|
|`recipient`|`address`|Address that will receive shares if approved|
|`amount`|`uint256`|Amount of assets deposited|
|`expirationTime`|`uint256`|Time after which deposit can be reclaimed|


### acceptDeposit

Accept a pending deposit


```solidity
function acceptDeposit(bytes32 depositId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`depositId`|`bytes32`|The deposit ID to accept|


### batchAcceptDeposits

Accept multiple pending deposits as a batch with equal share accounting


```solidity
function batchAcceptDeposits(bytes32[] calldata depositIds) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`depositIds`|`bytes32[]`|Array of deposit IDs to accept|


### refundDeposit

Refund a pending deposit


```solidity
function refundDeposit(bytes32 depositId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`depositId`|`bytes32`|The deposit ID to refund|


### batchRefundDeposits

Refund multiple pending deposits in a batch


```solidity
function batchRefundDeposits(bytes32[] calldata depositIds) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`depositIds`|`bytes32[]`|Array of deposit IDs to refund|


### reclaimDeposit

Allow a user to reclaim their expired deposit


```solidity
function reclaimDeposit(bytes32 depositId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`depositId`|`bytes32`|The deposit ID to reclaim|


### getPendingDeposit

Get the details of a pending deposit


```solidity
function getPendingDeposit(bytes32 depositId) external view returns (PendingDeposit memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`depositId`|`bytes32`|The deposit ID|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`PendingDeposit`|The deposit details|


## Events
### DepositReceived

```solidity
event DepositReceived(
    bytes32 indexed depositId,
    address indexed depositor,
    address indexed recipient,
    uint256 assets,
    uint256 expirationTime
);
```

### DepositAccepted

```solidity
event DepositAccepted(bytes32 indexed depositId, address indexed recipient, uint256 assets);
```

### DepositRefunded

```solidity
event DepositRefunded(bytes32 indexed depositId, address indexed depositor, uint256 assets);
```

### DepositReclaimed

```solidity
event DepositReclaimed(bytes32 indexed depositId, address indexed depositor, uint256 assets);
```

### BatchDepositsAccepted

```solidity
event BatchDepositsAccepted(bytes32[] depositIds, uint256 totalAssets);
```

### BatchDepositsRefunded

```solidity
event BatchDepositsRefunded(bytes32[] depositIds, uint256 totalAssets);
```

## Errors
### Unauthorized

```solidity
error Unauthorized();
```

### DepositNotFound

```solidity
error DepositNotFound();
```

### DepositNotPending

```solidity
error DepositNotPending();
```

### InvalidAddress

```solidity
error InvalidAddress();
```

### InvalidArrayLengths

```solidity
error InvalidArrayLengths();
```

### BatchFailed

```solidity
error BatchFailed();
```

## Structs
### PendingDeposit
Struct to track pending deposit information


```solidity
struct PendingDeposit {
    address depositor;
    address recipient;
    uint256 assetAmount;
    uint96 expirationTime;
    uint96 atRound;
    DepositState state;
}
```

## Enums
### DepositState
Enum to track the deposit state


```solidity
enum DepositState {
    PENDING,
    ACCEPTED,
    REFUNDED
}
```

