// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {ForcibleWithdrawRWA} from "../src/token/ForcibleWithdrawRWA.sol";
import {ForcibleWithdrawRWAStrategy} from "../src/strategy/ForcibleWithdrawRWAStrategy.sol";
import {Registry} from "../src/registry/Registry.sol";
import {RoleManager} from "../src/auth/RoleManager.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockReporter} from "../src/mocks/MockReporter.sol";

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
    address receiver = makeAddr("receiver");

    uint256 constant INITIAL_BALANCE = 1000e6; // 1000 USDC

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

        vm.stopPrank();

        // Get conduit address and have users approve it
        address conduit = registry.conduit();

        vm.prank(user1);
        asset.approve(conduit, type(uint256).max);

        vm.prank(user2);
        asset.approve(conduit, type(uint256).max);

        // Strategy needs to approve token for withdrawals
        vm.prank(address(strategy));
        asset.approve(address(token), type(uint256).max);
    }

    function test_ForceRedeem_SingleUser() public {
        // User deposits
        uint256 depositAmount = 100e6;
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
        uint256 depositAmount = 100e6;
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
        uint256 depositAmount = 100e6;
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

    function test_BatchForceRedeem() public {
        // Both users deposit
        uint256 depositAmount = 100e6;
        vm.prank(user1);
        uint256 shares1 = token.deposit(depositAmount, user1);

        vm.prank(user2);
        uint256 shares2 = token.deposit(depositAmount, user2);

        // Prepare batch parameters
        uint256[] memory shares = new uint256[](2);
        shares[0] = shares1;
        shares[1] = shares2 / 2; // Half of user2's shares

        address[] memory accounts = new address[](2);
        accounts[0] = user1;
        accounts[1] = user2;

        address[] memory receivers = new address[](2);
        receivers[0] = receiver;
        receivers[1] = receiver;

        // Manager batch force redeems
        vm.prank(manager);
        uint256[] memory assets = strategy.batchForceRedeem(shares, accounts, receivers);

        // Verify results
        assertEq(assets[0], depositAmount);
        assertEq(assets[1], depositAmount / 2);
        assertEq(token.balanceOf(user1), 0);
        assertEq(token.balanceOf(user2), shares2 / 2);
        assertEq(asset.balanceOf(receiver), depositAmount + depositAmount / 2);
    }

    function test_ForceRedeem_RevertNonManager() public {
        // User deposits
        vm.prank(user1);
        uint256 shares = token.deposit(100e6, user1);

        // Non-manager tries to force redeem
        vm.expectRevert();
        vm.prank(user2);
        strategy.forceRedeem(shares, user1, receiver);
    }

    function test_ForceRedeem_EmitsEvents() public {
        // User deposits
        vm.prank(user1);
        uint256 shares = token.deposit(100e6, user1);

        // Calculate expected assets
        uint256 expectedAssets = token.previewRedeem(shares);

        // Expect both events
        vm.expectEmit(true, true, true, true);
        emit ForcibleWithdrawRWA.ForcedWithdrawal(user1, receiver, shares, expectedAssets, address(strategy));

        // Manager force redeems
        vm.prank(manager);
        strategy.forceRedeem(shares, user1, receiver);
    }

    function test_ForceRedeem_ZeroAddress() public {
        // User deposits
        vm.prank(user1);
        uint256 shares = token.deposit(100e6, user1);

        // Try force redeem with zero account
        vm.prank(manager);
        vm.expectRevert();
        strategy.forceRedeem(shares, address(0), receiver);

        // Try force redeem with zero receiver
        vm.prank(manager);
        vm.expectRevert();
        strategy.forceRedeem(shares, user1, address(0));
    }

    function test_ForceRedeem_ZeroShares() public {
        // User deposits
        vm.prank(user1);
        token.deposit(100e6, user1);

        // Try force redeem with zero shares
        vm.prank(manager);
        vm.expectRevert();
        strategy.forceRedeem(0, user1, receiver);
    }
}
