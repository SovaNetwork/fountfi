// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {ForcibleWithdrawRWA} from "../src/token/ForcibleWithdrawRWA.sol";
import {ForcibleWithdrawRWAStrategy} from "../src/strategy/ForcibleWithdrawRWAStrategy.sol";
import {Registry} from "../src/registry/Registry.sol";
import {RoleManager} from "../src/auth/RoleManager.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {ERC4626} from "solady/tokens/ERC4626.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockReporter} from "../src/mocks/MockReporter.sol";
import {tRWA} from "../src/token/tRWA.sol";
import {ItRWA} from "../src/token/ItRWA.sol";
import {ManagedWithdrawRWA} from "../src/token/ManagedWithdrawRWA.sol";
import {MockHook} from "../src/mocks/hooks/MockHook.sol";
import {IHook} from "../src/hooks/IHook.sol";

/**
 * @title TrackingHook
 * @notice Hook that tracks withdraw operations for testing
 */
contract TrackingHook is IHook {
    bool public wasWithdrawCalled;
    address public lastWithdrawToken;
    address public lastWithdrawOperator;
    uint256 public lastWithdrawAssets;
    address public lastWithdrawReceiver;
    address public lastWithdrawOwner;

    function onBeforeDeposit(address, address, uint256, address) external pure override returns (HookOutput memory) {
        return HookOutput(true, "");
    }

    function onBeforeWithdraw(address token, address operator, uint256 assets, address receiver, address owner)
        external
        override
        returns (HookOutput memory)
    {
        wasWithdrawCalled = true;
        lastWithdrawToken = token;
        lastWithdrawOperator = operator;
        lastWithdrawAssets = assets;
        lastWithdrawReceiver = receiver;
        lastWithdrawOwner = owner;
        return HookOutput(true, "");
    }

    function onBeforeTransfer(address, address, address, uint256) external pure override returns (HookOutput memory) {
        return HookOutput(true, "");
    }

    function name() external pure override returns (string memory) {
        return "TrackingHook";
    }

    function hookId() external pure override returns (bytes32) {
        return keccak256("TrackingHook");
    }
}

/**
 * @title ForcibleWithdrawRWATest
 * @notice Comprehensive tests for ForcibleWithdrawRWA contract to achieve 100% branch coverage
 */
contract ForcibleWithdrawRWATest is Test {
    ForcibleWithdrawRWAStrategy strategy;
    ForcibleWithdrawRWA token;
    Registry registry;
    RoleManager roleManager;
    MockERC20 asset;
    MockReporter reporter;

    address owner = makeAddr("owner");
    address manager = makeAddr("manager");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");
    address receiver = makeAddr("receiver");

    uint256 constant INITIAL_BALANCE = 10000e6; // 10,000 USDC

    // Hook operation types
    bytes32 public constant OP_WITHDRAW = keccak256("WITHDRAW_OPERATION");

    function setUp() public {
        vm.startPrank(owner);

        // Deploy infrastructure
        roleManager = new RoleManager();
        registry = new Registry(address(roleManager));
        roleManager.initializeRegistry(address(registry));
        asset = new MockERC20("USDC", "USDC", 6);
        // Price per share needs to account for decimal difference
        // USDC has 6 decimals, shares have 18 decimals
        // So 1 share = 1e-12 USDC in 18 decimal format
        reporter = new MockReporter(1e6); // 1e6 means 1 share = 1e-12 assets

        // Deploy strategy using clone pattern
        address implementation = address(new ForcibleWithdrawRWAStrategy());

        // Grant necessary roles to owner
        roleManager.grantRole(owner, roleManager.PROTOCOL_ADMIN());
        roleManager.grantRole(owner, roleManager.STRATEGY_ADMIN());
        roleManager.grantRole(owner, roleManager.STRATEGY_OPERATOR());

        // Allow the asset and strategy implementation
        registry.setAsset(address(asset), 6); // 6 decimals for USDC
        registry.setStrategy(implementation, true);

        // Clone and initialize
        bytes memory initData = abi.encode(address(reporter));
        (address strategyAddr,) = registry.deploy(implementation, "Test RWA", "tRWA", address(asset), manager, initData);
        strategy = ForcibleWithdrawRWAStrategy(payable(strategyAddr));

        // Get deployed token
        token = ForcibleWithdrawRWA(address(strategy.sToken()));

        // Setup users with assets
        asset.mint(user1, INITIAL_BALANCE);
        asset.mint(user2, INITIAL_BALANCE);
        asset.mint(user3, INITIAL_BALANCE);

        vm.stopPrank();

        // Get conduit address and have users approve it
        address conduit = registry.conduit();

        vm.prank(user1);
        asset.approve(conduit, type(uint256).max);

        vm.prank(user2);
        asset.approve(conduit, type(uint256).max);

        vm.prank(user3);
        asset.approve(conduit, type(uint256).max);

        // Strategy needs to approve token for withdrawals
        vm.prank(address(strategy));
        asset.approve(address(token), type(uint256).max);
    }

    // ============ Constructor Tests ============

    function test_Constructor() public {
        // Deploy a fresh token to test constructor
        ForcibleWithdrawRWA newToken =
            new ForcibleWithdrawRWA("Test Token", "TEST", address(asset), 6, address(strategy));

        assertEq(newToken.name(), "Test Token");
        assertEq(newToken.symbol(), "TEST");
        assertEq(newToken.asset(), address(asset));
        assertEq(newToken.decimals(), 18); // ERC4626 always uses 18 decimals
        assertEq(newToken.strategy(), address(strategy));
    }

    // ============ ForceRedeem Tests ============

    function test_ForceRedeem_Success() public {
        // User deposits
        uint256 depositAmount = 1000e6;
        vm.prank(user1);
        uint256 shares = token.deposit(depositAmount, user1);

        assertEq(token.balanceOf(user1), shares);
        assertEq(asset.balanceOf(user1), INITIAL_BALANCE - depositAmount);

        // Check strategy balance after deposit
        assertEq(asset.balanceOf(address(strategy)), depositAmount);

        // Manager force redeems
        vm.prank(manager);
        uint256 assets = strategy.forceRedeem(shares, user1, receiver);

        // Verify results
        assertEq(assets, depositAmount);
        assertEq(token.balanceOf(user1), 0);
        assertEq(asset.balanceOf(receiver), depositAmount);
    }

    function test_ForceRedeem_PartialShares() public {
        // User deposits
        uint256 depositAmount = 1000e6;
        vm.prank(user1);
        uint256 totalShares = token.deposit(depositAmount, user1);

        // Manager force redeems half
        uint256 halfShares = totalShares / 2;
        vm.prank(manager);
        uint256 assets = strategy.forceRedeem(halfShares, user1, receiver);

        // Verify results
        assertEq(assets, depositAmount / 2);
        assertEq(token.balanceOf(user1), totalShares - halfShares);
        assertEq(asset.balanceOf(receiver), depositAmount / 2);
    }

    function test_ForceRedeem_ExceedsBalance() public {
        // User deposits
        uint256 depositAmount = 1000e6;
        vm.prank(user1);
        uint256 shares = token.deposit(depositAmount, user1);

        // Manager tries to force redeem more than balance
        vm.prank(manager);
        uint256 assets = strategy.forceRedeem(shares * 2, user1, receiver);

        // Should cap at user's balance
        assertEq(assets, depositAmount);
        assertEq(token.balanceOf(user1), 0);
        assertEq(asset.balanceOf(receiver), depositAmount);
    }

    function test_ForceRedeem_ZeroAccountAddress() public {
        // User deposits
        vm.prank(user1);
        uint256 shares = token.deposit(1000e6, user1);

        // Try force redeem with zero account
        vm.prank(manager);
        vm.expectRevert(ItRWA.InvalidAddress.selector);
        strategy.forceRedeem(shares, address(0), receiver);
    }

    function test_ForceRedeem_ZeroReceiverAddress() public {
        // User deposits
        vm.prank(user1);
        uint256 shares = token.deposit(1000e6, user1);

        // Try force redeem with zero receiver
        vm.prank(manager);
        vm.expectRevert(ItRWA.InvalidAddress.selector);
        strategy.forceRedeem(shares, user1, address(0));
    }

    function test_ForceRedeem_ZeroShares() public {
        // User deposits
        vm.prank(user1);
        token.deposit(1000e6, user1);

        // Try force redeem with zero shares
        vm.prank(manager);
        vm.expectRevert(ForcibleWithdrawRWA.InvalidAmount.selector);
        strategy.forceRedeem(0, user1, receiver);
    }

    function test_ForceRedeem_NotStrategy() public {
        // User deposits
        vm.prank(user1);
        uint256 shares = token.deposit(1000e6, user1);

        // Try to call forceRedeem directly on token (not through strategy)
        vm.prank(user1);
        vm.expectRevert(tRWA.NotStrategyAdmin.selector);
        token.forceRedeem(shares, user1, receiver);
    }

    function test_ForceRedeem_NotManager() public {
        // User deposits
        vm.prank(user1);
        uint256 shares = token.deposit(1000e6, user1);

        // Non-manager tries to force redeem
        vm.prank(user2);
        vm.expectRevert();
        strategy.forceRedeem(shares, user1, receiver);
    }

    function test_ForceRedeem_EmitsEvents() public {
        // User deposits
        vm.prank(user1);
        uint256 shares = token.deposit(1000e6, user1);

        // Calculate expected assets
        uint256 expectedAssets = token.previewRedeem(shares);

        // Expect both Withdraw and ForcedWithdrawal events
        vm.expectEmit(true, true, true, true);
        emit ERC4626.Withdraw(address(strategy), receiver, user1, expectedAssets, shares);

        vm.expectEmit(true, true, true, true);
        emit ForcibleWithdrawRWA.ForcedWithdrawal(user1, receiver, shares, expectedAssets, address(strategy));

        // Manager force redeems
        vm.prank(manager);
        strategy.forceRedeem(shares, user1, receiver);
    }

    function test_ForceRedeem_WithHooks() public {
        // User deposits
        vm.prank(user1);
        uint256 shares = token.deposit(1000e6, user1);

        // Add a tracking hook
        TrackingHook trackingHook = new TrackingHook();
        vm.prank(address(strategy));
        token.addOperationHook(OP_WITHDRAW, address(trackingHook));

        // Manager force redeems
        vm.prank(manager);
        uint256 assets = strategy.forceRedeem(shares, user1, receiver);

        // Verify hook was NOT called - forceRedeem bypasses hooks to ensure it cannot be blocked
        assertFalse(trackingHook.wasWithdrawCalled());

        // Verify the redemption still succeeded
        assertEq(assets, 1000e6);
        assertEq(token.balanceOf(user1), 0);
        assertEq(asset.balanceOf(receiver), 1000e6);
    }

    function test_ForceRedeem_WithFailingHook() public {
        // User deposits
        vm.prank(user1);
        uint256 shares = token.deposit(1000e6, user1);

        // Add a rejecting hook
        MockHook rejectingHook = new MockHook(false, "Force redeem blocked");
        vm.prank(address(strategy));
        token.addOperationHook(OP_WITHDRAW, address(rejectingHook));

        // Manager force redeems - should succeed despite rejecting hook
        vm.prank(manager);
        uint256 assets = strategy.forceRedeem(shares, user1, receiver);

        // Verify redemption succeeded - hooks are bypassed for force redemption
        assertEq(assets, 1000e6);
        assertEq(token.balanceOf(user1), 0);
        assertEq(asset.balanceOf(receiver), 1000e6);
    }

    function test_ForceRedeem_ZeroBalance() public {
        // Try to force redeem from user with no balance
        vm.prank(manager);
        uint256 assets = strategy.forceRedeem(1000e18, user1, receiver);

        // Should return 0 assets
        assertEq(assets, 0);
        assertEq(token.balanceOf(user1), 0);
        assertEq(asset.balanceOf(receiver), 0);
    }

    // ============ BatchForceRedeem Tests ============

    function test_BatchForceRedeem_Success() public {
        // Multiple users deposit
        uint256 depositAmount = 1000e6;
        vm.prank(user1);
        uint256 shares1 = token.deposit(depositAmount, user1);

        vm.prank(user2);
        uint256 shares2 = token.deposit(depositAmount * 2, user2);

        vm.prank(user3);
        uint256 shares3 = token.deposit(depositAmount * 3, user3);

        // Prepare batch parameters
        uint256[] memory shares = new uint256[](3);
        shares[0] = shares1;
        shares[1] = shares2 / 2; // Half of user2's shares
        shares[2] = shares3; // All of user3's shares

        address[] memory accounts = new address[](3);
        accounts[0] = user1;
        accounts[1] = user2;
        accounts[2] = user3;

        address[] memory receivers = new address[](3);
        receivers[0] = receiver;
        receivers[1] = user2; // User2 receives their own assets
        receivers[2] = receiver;

        // Manager batch force redeems
        vm.prank(manager);
        uint256[] memory assets = strategy.batchForceRedeem(shares, accounts, receivers);

        // Verify results
        assertEq(assets[0], depositAmount);
        assertEq(assets[1], depositAmount); // Half of 2x deposit
        assertEq(assets[2], depositAmount * 3);
        assertEq(token.balanceOf(user1), 0);
        assertEq(token.balanceOf(user2), shares2 / 2);
        assertEq(token.balanceOf(user3), 0);
        assertEq(asset.balanceOf(receiver), depositAmount + depositAmount * 3);
        assertEq(asset.balanceOf(user2), INITIAL_BALANCE - depositAmount * 2 + depositAmount);
    }

    function test_BatchForceRedeem_ArrayLengthMismatch_Shares() public {
        uint256[] memory shares = new uint256[](2);
        address[] memory accounts = new address[](3); // Different length
        address[] memory receivers = new address[](3);

        vm.prank(manager);
        vm.expectRevert(ForcibleWithdrawRWA.ArrayLengthMismatch.selector);
        strategy.batchForceRedeem(shares, accounts, receivers);
    }

    function test_BatchForceRedeem_ArrayLengthMismatch_Receivers() public {
        uint256[] memory shares = new uint256[](2);
        address[] memory accounts = new address[](2);
        address[] memory receivers = new address[](3); // Different length

        vm.prank(manager);
        vm.expectRevert(ForcibleWithdrawRWA.ArrayLengthMismatch.selector);
        strategy.batchForceRedeem(shares, accounts, receivers);
    }

    function test_BatchForceRedeem_ZeroAccountAddress() public {
        // User deposits
        vm.prank(user1);
        token.deposit(1000e6, user1);

        uint256[] memory shares = new uint256[](2);
        shares[0] = 100e18;
        shares[1] = 100e18;

        address[] memory accounts = new address[](2);
        accounts[0] = user1;
        accounts[1] = address(0); // Zero address

        address[] memory receivers = new address[](2);
        receivers[0] = receiver;
        receivers[1] = receiver;

        vm.prank(manager);
        vm.expectRevert(ItRWA.InvalidAddress.selector);
        strategy.batchForceRedeem(shares, accounts, receivers);
    }

    function test_BatchForceRedeem_ZeroReceiverAddress() public {
        // User deposits
        vm.prank(user1);
        token.deposit(1000e6, user1);

        uint256[] memory shares = new uint256[](2);
        shares[0] = 100e18;
        shares[1] = 100e18;

        address[] memory accounts = new address[](2);
        accounts[0] = user1;
        accounts[1] = user1;

        address[] memory receivers = new address[](2);
        receivers[0] = receiver;
        receivers[1] = address(0); // Zero address

        vm.prank(manager);
        vm.expectRevert(ItRWA.InvalidAddress.selector);
        strategy.batchForceRedeem(shares, accounts, receivers);
    }

    function test_BatchForceRedeem_ZeroShares() public {
        // User deposits
        vm.prank(user1);
        token.deposit(1000e6, user1);

        uint256[] memory shares = new uint256[](2);
        shares[0] = 100e18;
        shares[1] = 0; // Zero shares

        address[] memory accounts = new address[](2);
        accounts[0] = user1;
        accounts[1] = user1;

        address[] memory receivers = new address[](2);
        receivers[0] = receiver;
        receivers[1] = receiver;

        vm.prank(manager);
        vm.expectRevert(ForcibleWithdrawRWA.InvalidAmount.selector);
        strategy.batchForceRedeem(shares, accounts, receivers);
    }

    function test_BatchForceRedeem_NotStrategy() public {
        uint256[] memory shares = new uint256[](1);
        address[] memory accounts = new address[](1);
        address[] memory receivers = new address[](1);

        // Try to call batchForceRedeem directly on token (not through strategy)
        vm.prank(user1);
        vm.expectRevert(tRWA.NotStrategyAdmin.selector);
        token.batchForceRedeem(shares, accounts, receivers);
    }

    function test_BatchForceRedeem_EmptyArrays() public {
        uint256[] memory shares = new uint256[](0);
        address[] memory accounts = new address[](0);
        address[] memory receivers = new address[](0);

        vm.prank(manager);
        uint256[] memory assets = strategy.batchForceRedeem(shares, accounts, receivers);

        assertEq(assets.length, 0);
    }

    function test_BatchForceRedeem_ExceedsBalance() public {
        // User deposits
        vm.prank(user1);
        uint256 actualShares = token.deposit(1000e6, user1);

        uint256[] memory shares = new uint256[](1);
        shares[0] = actualShares * 2; // Request more than balance

        address[] memory accounts = new address[](1);
        accounts[0] = user1;

        address[] memory receivers = new address[](1);
        receivers[0] = receiver;

        vm.prank(manager);
        uint256[] memory assets = strategy.batchForceRedeem(shares, accounts, receivers);

        // Should cap at user's balance
        assertEq(assets[0], 1000e6);
        assertEq(token.balanceOf(user1), 0);
    }

    function test_BatchForceRedeem_WithHooks() public {
        // User deposits
        vm.prank(user1);
        uint256 shares1 = token.deposit(1000e6, user1);

        // Add a tracking hook
        TrackingHook trackingHook = new TrackingHook();
        vm.prank(address(strategy));
        token.addOperationHook(OP_WITHDRAW, address(trackingHook));

        uint256[] memory shares = new uint256[](1);
        shares[0] = shares1;

        address[] memory accounts = new address[](1);
        accounts[0] = user1;

        address[] memory receivers = new address[](1);
        receivers[0] = receiver;

        vm.prank(manager);
        uint256[] memory assets = strategy.batchForceRedeem(shares, accounts, receivers);

        // Verify hook was NOT called - batchForceRedeem also bypasses hooks
        assertFalse(trackingHook.wasWithdrawCalled());

        // Verify the redemption still succeeded
        assertEq(assets[0], 1000e6);
        assertEq(token.balanceOf(user1), 0);
        assertEq(asset.balanceOf(receiver), 1000e6);
    }

    function test_BatchForceRedeem_EmitsEvents() public {
        // User deposits
        vm.prank(user1);
        uint256 shares1 = token.deposit(1000e6, user1);

        uint256[] memory shares = new uint256[](1);
        shares[0] = shares1;

        address[] memory accounts = new address[](1);
        accounts[0] = user1;

        address[] memory receivers = new address[](1);
        receivers[0] = receiver;

        uint256 expectedAssets = token.previewRedeem(shares1);

        // Expect events
        vm.expectEmit(true, true, true, true);
        emit ERC4626.Withdraw(address(strategy), receiver, user1, expectedAssets, shares1);

        vm.expectEmit(true, true, true, true);
        emit ForcibleWithdrawRWA.ForcedWithdrawal(user1, receiver, shares1, expectedAssets, address(strategy));

        vm.prank(manager);
        strategy.batchForceRedeem(shares, accounts, receivers);
    }

    // ============ ManagedWithdrawRWA Inherited Tests ============

    function test_Withdraw_AlwaysReverts() public {
        uint256 assets = 1000e6;

        vm.prank(address(strategy));
        vm.expectRevert(ManagedWithdrawRWA.UseRedeem.selector);
        token.withdraw(assets, user1, user1);
    }

    function test_Redeem_WithMinAssets() public {
        // User deposits
        vm.prank(user1);
        uint256 shares = token.deposit(1000e6, user1);

        // User approves strategy
        vm.prank(user1);
        token.approve(address(strategy), shares);

        // Strategy redeems with min assets check
        vm.prank(address(strategy));
        uint256 assets = token.redeem(shares / 2, user1, user1, 400e6);

        assertGt(assets, 400e6);
        assertEq(token.balanceOf(user1), shares / 2);
    }

    function test_Redeem_InsufficientOutputAssets() public {
        // User deposits
        vm.prank(user1);
        uint256 shares = token.deposit(1000e6, user1);

        // User approves strategy
        vm.prank(user1);
        token.approve(address(strategy), shares);

        // Strategy tries to redeem with too high min assets
        vm.prank(address(strategy));
        vm.expectRevert(ManagedWithdrawRWA.InsufficientOutputAssets.selector);
        token.redeem(shares / 2, user1, user1, 600e6); // Expect more than possible
    }

    // ============ Integration Tests ============

    function test_CompleteForceRedemptionFlow() public {
        // Multiple users deposit different amounts
        vm.prank(user1);
        uint256 shares1 = token.deposit(1500e6, user1);

        vm.prank(user2);
        uint256 shares2 = token.deposit(2500e6, user2);

        vm.prank(user3);
        uint256 shares3 = token.deposit(500e6, user3);

        // Check total assets in strategy
        assertEq(asset.balanceOf(address(strategy)), 4500e6);

        // Manager force redeems all users
        uint256[] memory shares = new uint256[](3);
        shares[0] = shares1;
        shares[1] = shares2;
        shares[2] = shares3;

        address[] memory accounts = new address[](3);
        accounts[0] = user1;
        accounts[1] = user2;
        accounts[2] = user3;

        address[] memory receivers = new address[](3);
        receivers[0] = receiver;
        receivers[1] = receiver;
        receivers[2] = receiver;

        vm.prank(manager);
        uint256[] memory assets = strategy.batchForceRedeem(shares, accounts, receivers);

        // Verify all users have no shares
        assertEq(token.balanceOf(user1), 0);
        assertEq(token.balanceOf(user2), 0);
        assertEq(token.balanceOf(user3), 0);

        // Verify receiver got all assets
        assertEq(asset.balanceOf(receiver), 4500e6);

        // Verify returned assets match deposits
        assertEq(assets[0], 1500e6);
        assertEq(assets[1], 2500e6);
        assertEq(assets[2], 500e6);
    }

    function test_MixedRedemptionAndForceRedemption() public {
        // User deposits
        vm.prank(user1);
        uint256 totalShares = token.deposit(2000e6, user1);

        // User voluntarily redeems half through normal process
        uint256 halfShares = totalShares / 2;
        vm.prank(user1);
        token.approve(address(strategy), halfShares);

        vm.prank(address(strategy));
        token.redeem(halfShares, user1, user1);

        assertEq(token.balanceOf(user1), halfShares);
        assertEq(asset.balanceOf(user1), INITIAL_BALANCE - 1000e6);

        // Manager force redeems the rest
        vm.prank(manager);
        uint256 forcedAssets = strategy.forceRedeem(halfShares, user1, receiver);

        assertEq(forcedAssets, 1000e6);
        assertEq(token.balanceOf(user1), 0);
        assertEq(asset.balanceOf(receiver), 1000e6);
    }

    function test_ForceRedeem_AfterTransfer() public {
        // User1 deposits
        vm.prank(user1);
        uint256 shares = token.deposit(1000e6, user1);

        // User1 transfers shares to user2
        vm.prank(user1);
        token.transfer(user2, shares);

        assertEq(token.balanceOf(user1), 0);
        assertEq(token.balanceOf(user2), shares);

        // Manager force redeems from user2
        vm.prank(manager);
        uint256 assets = strategy.forceRedeem(shares, user2, receiver);

        assertEq(assets, 1000e6);
        assertEq(token.balanceOf(user2), 0);
        assertEq(asset.balanceOf(receiver), 1000e6);
    }

    // ============ Helper Functions ============

    function _depositAsUser(address user, uint256 amount) internal {
        vm.startPrank(user);
        asset.approve(registry.conduit(), amount);
        token.deposit(amount, user);
        vm.stopPrank();
    }
}
