# GatedMintRWA
[Git Source](https://github.com/SovaNetwork/fountfi/blob/58164582109e1a7de75ddd7e30bfe628ac79d7fd/src/token/GatedMintRWA.sol)

**Inherits:**
[tRWA](/src/token/tRWA.sol/contract.tRWA.md)

FIXME: Add slippage protection before using in production!

Extension of tRWA that implements a two-phase deposit process using an Escrow

*Deposits are first collected and stored in Escrow; shares are only minted upon acceptance*


## State Variables
### depositIds
Deposit tracking (IDs only - Escrow has full state)


```solidity
bytes32[] public depositIds;
```


### userDepositIds
Mapping of user addresses to their deposit IDs


```solidity
mapping(address => bytes32[]) public userDepositIds;
```


### sequenceNum
Monotonically-increasing sequence number to guarantee unique depositIds


```solidity
uint256 private sequenceNum;
```


### depositExpirationPeriod
Deposit expiration time (in seconds) - default to 7 days


```solidity
uint256 public depositExpirationPeriod = 7 days;
```


### MAX_DEPOSIT_EXPIRATION_PERIOD
Maximum deposit expiration period


```solidity
uint256 public constant MAX_DEPOSIT_EXPIRATION_PERIOD = 30 days;
```


### escrow
The escrow contract that holds assets and manages deposits


```solidity
address public immutable escrow;
```


## Functions
### constructor

Constructor


```solidity
constructor(string memory name_, string memory symbol_, address asset_, uint8 assetDecimals_, address strategy_)
    tRWA(name_, symbol_, asset_, assetDecimals_, strategy_);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`name_`|`string`|The name of the token|
|`symbol_`|`string`|The symbol of the token|
|`asset_`|`address`|The address of the asset|
|`assetDecimals_`|`uint8`|The decimals of the asset|
|`strategy_`|`address`|The address of the strategy|


### setDepositExpirationPeriod

Sets the period after which deposits expire and can be reclaimed


```solidity
function setDepositExpirationPeriod(uint256 newExpirationPeriod) external onlyStrategy;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newExpirationPeriod`|`uint256`|New expiration period in seconds|


### _deposit

Override of _deposit to store deposit info instead of minting immediately


```solidity
function _deposit(address by, address to, uint256 assets, uint256) internal override nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`by`|`address`|Address of the sender|
|`to`|`address`|Address of the recipient|
|`assets`|`uint256`|Amount of assets to deposit|
|`<none>`|`uint256`||


### mintShares

Mint shares for an accepted deposit (called by Escrow)


```solidity
function mintShares(address recipient, uint256 assetAmount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`|The recipient of shares|
|`assetAmount`|`uint256`|The asset amount|


### batchMintShares

Mint shares for a batch of accepted deposits with equal share pricing


```solidity
function batchMintShares(address[] calldata recipients, uint256[] calldata assetAmounts, uint256 totalAssets)
    external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipients`|`address[]`|Array of recipient addresses|
|`assetAmounts`|`uint256[]`|Array of asset amounts aligned with recipients|
|`totalAssets`|`uint256`|Total assets in the batch (sum of assetAmounts)|


### getUserPendingDeposits

Get all pending deposit IDs for a specific user


```solidity
function getUserPendingDeposits(address user) external view returns (bytes32[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The user address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32[]`|Array of deposit IDs that are still pending|


### getDepositDetails

Get details for a specific deposit (from Escrow)


```solidity
function getDepositDetails(bytes32 depositId)
    public
    view
    returns (
        address depositor,
        address recipient,
        uint256 assetAmount,
        uint256 expirationTime,
        GatedMintEscrow.DepositState state
    );
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`depositId`|`bytes32`|The unique identifier of the deposit|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`depositor`|`address`|The address that initiated the deposit|
|`recipient`|`address`|The address that will receive shares if approved|
|`assetAmount`|`uint256`|The amount of assets deposited|
|`expirationTime`|`uint256`|The timestamp after which deposit can be reclaimed|
|`state`|`GatedMintEscrow.DepositState`|The current state of the deposit (0=PENDING, 1=ACCEPTED, 2=REFUNDED)|


## Events
### DepositPending

```solidity
event DepositPending(bytes32 indexed depositId, address indexed depositor, address indexed recipient, uint256 assets);
```

### DepositExpirationPeriodUpdated

```solidity
event DepositExpirationPeriodUpdated(uint256 oldPeriod, uint256 newPeriod);
```

### BatchSharesMinted

```solidity
event BatchSharesMinted(uint256 totalAssets, uint256 totalShares);
```

## Errors
### NotEscrow

```solidity
error NotEscrow();
```

### EscrowNotSet

```solidity
error EscrowNotSet();
```

### InvalidExpirationPeriod

```solidity
error InvalidExpirationPeriod();
```

### InvalidArrayLengths

```solidity
error InvalidArrayLengths();
```

