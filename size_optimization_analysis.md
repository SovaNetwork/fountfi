# Contract Size Optimization Analysis

## Executive Summary

This analysis identifies multiple optimization opportunities across the Fountfi codebase that can reduce contract sizes. Key findings include unused imports, functions that can be made external, redundant code, and areas where storage/gas optimizations can be applied.

## 1. Unused Imports

### GatedMintRWA.sol
- **SafeTransferLib** is imported but never used
- The contract inherits from tRWA which already has SafeTransferLib functionality

### GatedMintRWAStrategy.sol
- **SafeTransferLib** import is not needed (already removed according to git history)

## 2. Public vs External Function Optimizations

### tRWA.sol
Several view functions can be changed from `public` to `external` to save bytecode:
- `name()` (line 116)
- `symbol()` (line 124)
- `asset()` (line 132)
- `totalAssets()` (line 160)

### GatedMintRWA.sol
- `getDepositDetails()` (line 263) - can be made `external` since it's not called internally

### BasicStrategy.sol
- `balance()` (line 113) - currently external virtual, but implementations could optimize

### BaseHook.sol
Hook functions are `public virtual` but could be `external virtual`:
- `onBeforeDeposit()` (line 57)
- `onBeforeWithdraw()` (line 70)
- `onBeforeTransfer()` (line 83)

## 3. String/Error Message Optimizations

### Current State
The contracts use custom errors which is already optimal. However, there are opportunities:

### tRWA.sol
- Consider using error codes instead of string reasons in `HookCheckFailed(string reason)`
- The string parameter adds significant bytecode

### Recommendation
Replace:
```solidity
error HookCheckFailed(string reason);
```
With:
```solidity
error HookCheckFailed(bytes32 reasonCode);
```

## 4. Redundant Code

### tRWA.sol - Hook System Analysis
The hook system has some redundancy that could be optimized:

1. **Duplicate Hook Loops**: The pattern of iterating through hooks is repeated in:
   - `_deposit()` (lines 178-187)
   - `_withdraw()` (lines 224-234)
   - `_beforeTokenTransfer()` (lines 389-398)

2. **Optimization**: Extract hook validation into an internal function:
```solidity
function _validateHooks(bytes32 operationType, bytes memory hookData) internal {
    HookInfo[] storage opHooks = operationHooks[operationType];
    for (uint256 i = 0; i < opHooks.length;) {
        // Hook validation logic
        unchecked { ++i; }
    }
    if (opHooks.length > 0) {
        lastExecutedBlock[operationType] = block.number;
    }
}
```

### GatedMintRWA.sol
- The `depositIds` array (line 48) appears unused after deposits are processed
- Consider removing if not needed for external tracking

## 5. Storage Optimizations

### tRWA.sol
1. **Struct Packing**: The `HookInfo` struct could be optimized:
```solidity
struct HookInfo {
    IHook hook;        // 20 bytes (address)
    uint256 addedAtBlock; // 32 bytes
}
```
Could pack better if `addedAtBlock` was `uint96` (sufficient for block numbers):
```solidity
struct HookInfo {
    IHook hook;        // 20 bytes
    uint96 addedAtBlock; // 12 bytes - packed in single slot
}
```

### GatedMintRWA.sol
- `sequenceNum` (line 54) could be `uint128` instead of `uint256`
- `depositExpirationPeriod` could be `uint64` (enough for timestamps)

## 6. Hook System Necessity Analysis

### Current Implementation
The hook system in tRWA adds significant complexity and bytecode:
- Three mappings for hook management
- Multiple functions for hook administration
- Hook validation in every transfer/deposit/withdraw

### Considerations for Removal
1. **If hooks are rarely used**: Consider making hooks an optional module
2. **Alternative**: Use a single hook instead of arrays of hooks
3. **Minimal approach**: Only support deposit/withdraw hooks, remove transfer hooks

### Recommendation
If the full hook system is necessary, consider:
- Making hook arrays fixed-size to avoid dynamic array operations
- Using a registry pattern where hooks are deployed separately

## 7. Modifier Optimizations

### BasicStrategy.sol
The `onlyManager` modifier (line 196) is simple and efficient.

### RoleManaged.sol
Role checking is already optimized through LibRoleManaged.

## 8. View Function Optimizations

### tRWA.sol
- `getHooksForOperation()` (line 353): Creates a new array in memory - consider returning the storage array directly if gas cost is acceptable
- `getHookInfoForOperation()` (line 371): Already returns storage array directly (good)

### GatedMintRWA.sol
- `getUserPendingDeposits()` (line 222): Uses assembly for array resizing (already optimized)

## 9. Additional Optimizations

### Import Optimization
Replace generic imports with specific imports where possible:
```solidity
// Instead of
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// Use
import {IERC20} from "solady/tokens/ERC20.sol";
```

### Constant Optimizations
In tRWA.sol, operation type constants are already optimized as `bytes32 constant`.

### Fallback Function
BasicStrategy has a `receive()` function (line 205) - ensure it's necessary.

## 10. Specific Contract Recommendations

### tRWA.sol
1. Remove unused SafeTransferLib functions by using specific imports
2. Make view functions external
3. Consider simplifying or modularizing the hook system
4. Pack HookInfo struct
5. Replace string reasons with bytes32 codes

### GatedMintRWA.sol
1. Remove SafeTransferLib import
2. Make getDepositDetails external
3. Optimize storage variables to smaller types
4. Remove depositIds if unused

### BasicStrategy.sol
1. Already well-optimized
2. Consider if all token management functions are necessary

### ReportedStrategy.sol
1. Well-optimized, minimal implementation
2. FixedPointMathLib usage is appropriate

## Implementation Priority

1. **High Impact, Low Risk**:
   - Remove unused imports
   - Change public to external for view functions
   - Pack structs where possible

2. **Medium Impact, Medium Risk**:
   - Simplify hook system
   - Use bytes32 instead of string for errors

3. **Lower Priority**:
   - Fixed-size arrays for hooks
   - Modularize hook system

## Estimated Size Savings

- Removing unused imports: ~200-500 bytes per import
- Public to external conversions: ~50-100 bytes per function
- Struct packing: ~100-200 bytes
- Hook system simplification: ~1-2KB potential savings
- String to bytes32 in errors: ~200-400 bytes

**Total potential savings: 2-4KB across all contracts**