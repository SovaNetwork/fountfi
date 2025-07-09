# tRWA
[Git Source](https://github.com/SovaNetwork/fountfi/blob/58164582109e1a7de75ddd7e30bfe628ac79d7fd/src/token/tRWA.sol)

**Inherits:**
ERC4626, [ItRWA](/src/token/ItRWA.sol/interface.ItRWA.md), ReentrancyGuard

Tokenized Real World Asset (tRWA) inheriting ERC4626 standard

*Each token represents a share in the underlying real-world fund*


## State Variables
### _symbol
Internal storage for token metadata


```solidity
string private _symbol;
```


### _name

```solidity
string private _name;
```


### _asset

```solidity
address private immutable _asset;
```


### _assetDecimals

```solidity
uint8 private immutable _assetDecimals;
```


### strategy
The strategy contract


```solidity
address public immutable strategy;
```


### OP_DEPOSIT
Operation type identifiers


```solidity
bytes32 public constant OP_DEPOSIT = keccak256("DEPOSIT_OPERATION");
```


### OP_WITHDRAW

```solidity
bytes32 public constant OP_WITHDRAW = keccak256("WITHDRAW_OPERATION");
```


### OP_TRANSFER

```solidity
bytes32 public constant OP_TRANSFER = keccak256("TRANSFER_OPERATION");
```


### operationHooks
Mapping of operation type to hook information


```solidity
mapping(bytes32 => HookInfo[]) public operationHooks;
```


### lastExecutedBlock
Mapping of operation type to the last block number it was executed


```solidity
mapping(bytes32 => uint256) public lastExecutedBlock;
```


## Functions
### constructor

Contract constructor


```solidity
constructor(string memory name_, string memory symbol_, address asset_, uint8 assetDecimals_, address strategy_);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`name_`|`string`|Token name|
|`symbol_`|`string`|Token symbol|
|`asset_`|`address`|Asset address|
|`assetDecimals_`|`uint8`|Decimals of the asset token|
|`strategy_`|`address`|Strategy address|


### name

Returns the name of the token


```solidity
function name() public view virtual override returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|Name of the token|


### symbol

Returns the symbol of the token


```solidity
function symbol() public view virtual override returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|Symbol of the token|


### asset

Returns the asset of the token


```solidity
function asset() public view virtual override(ERC4626, ItRWA) returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Asset of the token|


### _underlyingDecimals

*Returns the decimals of the underlying asset token.*


```solidity
function _underlyingDecimals() internal view virtual override returns (uint8);
```

### _decimalsOffset

*Returns the offset to adjust share decimals relative to asset decimals.
Ensures that `_underlyingDecimals() + _decimalsOffset()` equals `decimals()` (18 for tRWA shares).*


```solidity
function _decimalsOffset() internal view virtual override returns (uint8);
```

### totalAssets

Returns the total amount of the underlying asset managed by the Vault.

*This value is expected by the base ERC4626 implementation to be in terms of asset's native decimals.*


```solidity
function totalAssets() public view override returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Total assets in terms of _asset|


### _deposit

Deposit assets into the token


```solidity
function _deposit(address by, address to, uint256 assets, uint256 shares) internal virtual override nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`by`|`address`|Address of the sender|
|`to`|`address`|Address of the receiver|
|`assets`|`uint256`|Amount of assets to deposit|
|`shares`|`uint256`|Amount of shares to mint|


### _withdraw

Withdraw assets from the token


```solidity
function _withdraw(address by, address to, address owner, uint256 assets, uint256 shares)
    internal
    virtual
    override
    nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`by`|`address`|Address of the sender|
|`to`|`address`|Address of the receiver|
|`owner`|`address`|Address of the owner|
|`assets`|`uint256`|Amount of assets to withdraw|
|`shares`|`uint256`|Amount of shares to withdraw|


### addOperationHook

Adds a new operation hook to the end of the list for a specific operation type.

*Callable only by the strategy contract.*


```solidity
function addOperationHook(bytes32 operationType, address newHookAddress) external onlyStrategy;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`operationType`|`bytes32`|The type of operation this hook applies to (e.g., OP_DEPOSIT).|
|`newHookAddress`|`address`|The address of the new hook contract to add.|


### removeOperationHook

Removes an operation hook from a specific operation type.

*Callable only by the strategy contract. Can only remove hooks that haven't processed operations.*


```solidity
function removeOperationHook(bytes32 operationType, uint256 index) external onlyStrategy nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`operationType`|`bytes32`|The type of operation to remove the hook from.|
|`index`|`uint256`|The index of the hook to remove.|


### reorderOperationHooks

Reorders the existing operation hooks for a specific operation type.

*Callable only by the strategy contract. The newOrderIndices array must be a permutation
of the current hook indices (0 to length-1) for the given operation type.*


```solidity
function reorderOperationHooks(bytes32 operationType, uint256[] calldata newOrderIndices)
    external
    onlyStrategy
    nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`operationType`|`bytes32`|The type of operation for which hooks are being reordered.|
|`newOrderIndices`|`uint256[]`|An array where newOrderIndices[i] specifies the OLD index of the hook that should now be at NEW position i.|


### getHooksForOperation

Gets all registered hook addresses for a specific operation type.


```solidity
function getHooksForOperation(bytes32 operationType) external view returns (address[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`operationType`|`bytes32`|The type of operation.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address[]`|An array of hook contract addresses.|


### getHookInfoForOperation

Gets detailed information about all hooks for a specific operation type.


```solidity
function getHookInfoForOperation(bytes32 operationType) external view returns (HookInfo[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`operationType`|`bytes32`|The type of operation.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`HookInfo[]`|hookInfos Array of HookInfo structs containing hook details.|


### _beforeTokenTransfer

*Hook that is called before any token transfer, including mints and burns.
We use this to apply OP_TRANSFER hooks.*


```solidity
function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override;
```

### _collect

Collect assets from the strategy


```solidity
function _collect(uint256 assets) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`|The amount of assets to collect|


### onlyStrategy


```solidity
modifier onlyStrategy();
```

## Events
### HookAdded

```solidity
event HookAdded(bytes32 indexed operationType, address indexed hookAddress, uint256 index);
```

### HookRemoved

```solidity
event HookRemoved(bytes32 indexed operationType, address indexed hookAddress);
```

### HooksReordered

```solidity
event HooksReordered(bytes32 indexed operationType, uint256[] newIndices);
```

## Errors
### HookCheckFailed

```solidity
error HookCheckFailed(string reason);
```

### NotStrategyAdmin

```solidity
error NotStrategyAdmin();
```

### HookAddressZero

```solidity
error HookAddressZero();
```

### ReorderInvalidLength

```solidity
error ReorderInvalidLength();
```

### ReorderIndexOutOfBounds

```solidity
error ReorderIndexOutOfBounds();
```

### ReorderDuplicateIndex

```solidity
error ReorderDuplicateIndex();
```

### HookHasProcessedOperations

```solidity
error HookHasProcessedOperations();
```

### HookIndexOutOfBounds

```solidity
error HookIndexOutOfBounds();
```

### InvalidDecimals

```solidity
error InvalidDecimals();
```

## Structs
### HookInfo
Hook information structure


```solidity
struct HookInfo {
    IHook hook;
    uint256 addedAtBlock;
}
```

