# Contract Size Reduction Plan

## Current Situation
The `GatedMintReportedStrategy` contract is currently **25,141 bytes**, which exceeds the EVM contract size limit of 24,576 bytes by **565 bytes**. We need to reduce the contract size without breaking functionality or changing business logic.

## Root Cause Analysis
The primary source of the contract size is that `GatedMintReportedStrategy` deploys `GatedMintRWA` using the `new` keyword, which embeds the entire creation bytecode (~19,819 bytes) of `GatedMintRWA` into the strategy contract. This is by far the largest contributor to the contract size.

## Contract Hierarchy
```
GatedMintReportedStrategy (25,141 bytes)
├── ReportedStrategy
│   └── BasicStrategy
│       └── CloneableRoleManaged
└── Deploys: GatedMintRWA
    ├── tRWA (base token with hooks)
    └── Deploys: GatedMintEscrow
```

## Optimization Plan

### Primary Solution: Factory Pattern (Est. 19,000+ bytes savings)

The most effective solution is to remove the token deployment from the strategy contract entirely by using a factory pattern:

1. **Create a Token Factory Contract**
   - Deploy a separate `tRWAFactory` contract that handles token deployments
   - The factory would have methods like `deployTRWA()`, `deployGatedMintRWA()`, etc.
   - This removes ~19,819 bytes from the strategy contract

2. **Modify Strategy Initialization**
   - Instead of deploying the token directly, the strategy would:
     - Either receive the token address as a parameter during initialization
     - Or call the factory to deploy and return the token address
   - This maintains the same functionality but drastically reduces contract size

3. **Benefits**
   - Immediate savings of ~19,000 bytes (well below the limit)
   - Cleaner separation of concerns
   - Reusable factory for other strategies
   - Can add new token types without modifying strategies

### Alternative Solutions

1. **Clone Pattern for Tokens**
   - Use minimal proxy pattern (EIP-1167) for token deployments
   - Deploy one implementation and create clones
   - Savings: ~19,000 bytes
   - Complexity: Requires refactoring token initialization

2. **CREATE2 with Precomputed Bytecode**
   - Deploy token bytecode separately and use CREATE2
   - More complex but maintains deterministic addresses

### Phase 1: Quick Wins (Est. 200-400 bytes savings)

1. **Remove Unused Import**
   - File: `src/token/GatedMintRWA.sol`
   - Action: Remove unused `SafeTransferLib` import
   - Risk: None
   - Savings: ~50 bytes

2. **Convert Public View Functions to External**
   - Files: `src/token/tRWA.sol`, `src/token/GatedMintRWA.sol`
   - Functions to change:
     - `tRWA`: `name()`, `symbol()`, `asset()`, `totalAssets()`
     - `GatedMintRWA`: `getDepositDetails()`
   - Risk: None (external is cheaper for external calls)
   - Savings: ~100-150 bytes

3. **Optimize Error Messages**
   - File: `src/token/tRWA.sol`
   - Action: Replace `error HookCheckFailed(string reason)` with `error HookCheckFailed(bytes32 reasonCode)`
   - Risk: Low (less descriptive errors, but can map codes to meanings)
   - Savings: ~100-200 bytes

### Phase 2: Moderate Optimizations (Est. 300-600 bytes savings)

4. **Storage Packing Optimizations**
   - File: `src/token/GatedMintRWA.sol`
   - Actions:
     - Change `sequenceNum` from `uint256` to `uint128`
     - Change `depositExpirationPeriod` from `uint256` to `uint64`
   - File: `src/token/tRWA.sol`
   - Actions:
     - Pack `HookInfo` struct: use `uint96` for `addedAtBlock` instead of `uint256`
   - Risk: Low (block numbers won't exceed uint96 for billions of years)
   - Savings: ~200-300 bytes

5. **Extract Duplicate Hook Validation Logic**
   - File: `src/token/tRWA.sol`
   - Action: Create internal function `_validateHooks()` to reduce code duplication
   - Risk: Low
   - Savings: ~100-300 bytes

### Phase 3: Structural Changes (Est. 500-1000+ bytes savings)

6. **Simplify Hook System** (Optional - Higher Risk)
   - File: `src/token/tRWA.sol`
   - Options:
     - Remove transfer hooks if not critical
     - Limit to single hook per operation instead of arrays
     - Use mapping instead of array for hooks
   - Risk: Medium (changes hook functionality)
   - Savings: ~500-1000 bytes

7. **Remove Unused State Variables**
   - File: `src/token/GatedMintRWA.sol`
   - Action: Remove `depositIds` array if not needed after processing
   - Risk: Low if confirmed unused
   - Savings: ~100-200 bytes

## Recommended Implementation Order

1. **Implement the Factory Pattern First**
   - This alone will solve the size issue completely
   - Create `tRWAFactory` contract
   - Update strategy to use factory instead of direct deployment
   - Test thoroughly as this is a significant architectural change

2. **Optional: Implement Quick Wins**
   - If you want additional optimizations, implement Phase 1 & 2
   - These provide marginal benefits but are good practices

## Expected Total Savings

- **Factory Pattern**: ~19,000 bytes (reduces contract to ~6,000 bytes)
- **Quick Optimizations**: 800-1,600 bytes additional
- **Total**: Contract would be well under 10,000 bytes (less than 50% of limit)

## Testing Requirements

After each optimization:
1. Run `forge build --sizes` to verify size reduction
2. Run `forge test` to ensure all tests pass
3. Deploy to a test environment to verify functionality

## Notes

- All proposed changes maintain the existing interfaces and business logic
- No changes to external function signatures
- Internal optimizations only
- Tests may need minor updates for error message changes