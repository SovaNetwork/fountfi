# Fountfi Foundry Project Guide

## Build Commands
- Build: `forge build`
- Test (all): `forge test`
- Test (single): `forge test --match-test test_Increment`
- Test (verbose): `forge test -vvv`
- Format: `forge fmt`
- Gas snapshot: `forge snapshot`
- Deploy: `forge script script/DeployProtocol.s.sol:DeployProtocolScript --rpc-url <url> --private-key <key>`

## Code Style Guidelines
- **Pragma**: Use `0.8.25` or higher
- **Imports**: Named using `{Contract} from "path"` syntax
- **Formatting**: 4-space indentation, braces on same line as declarations
- **Types**: Always use explicit types (uint256 instead of uint)
- **Naming**:
  - Contracts: PascalCase (tRWA, SimpleRWA)
  - Functions: camelCase (setNumber, updateNav)
  - Tests: prefix with `test_` or `testFuzz_`
  - Deploy scripts: suffix with `.s.sol`
- **Visibility**: Always declare explicitly (public, internal, private)
- **Error handling**: Use named errors with revert statements
- **Documentation**: SPDX license identifier required for all files
- **Events**: Emit events for important state changes

## Code Change Protocol

  - **STRICT RULE:** NEVER write or modify actual code files unless explicitly instructed with the exact phrase "execute
  the changes".
  - When discussing potential changes, only provide design sketches, outlines, and explanations.
  - For design documents, write to separate `.md` files when requested.
  - When asked to "sketch" a solution, provide pseudocode, explanatory text, or code snippets within a `.md` file only, not actual implementation files.
  - Always confirm before implementing any changes with "Should I proceed with executing these changes?"
  - Remember that even draft implementations should be put in files with extensions like `.draft.sol` or `.sketch.md` to
  avoid confusion with actual implementation files.

## Guidelines for Claude

- When fixing tests, try to only change the test files. If it's necessary to update the smart contracts, stop, explain why, and confirm before proceeding.
- If a prompt mentions that code was changed, always re-read the file.
- Commit often, so that we always have checkpoints to return to. Make single-line, brief commits explaining code changes.
