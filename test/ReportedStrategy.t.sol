// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BaseFountfiTest} from "./BaseFountfiTest.t.sol";
import {ReportedStrategy} from "../src/strategy/ReportedStrategy.sol";
import {BasicStrategy} from "../src/strategy/BasicStrategy.sol";
import {IStrategy} from "../src/strategy/IStrategy.sol";
import {tRWA} from "../src/token/tRWA.sol";
import {RoleManager} from "../src/auth/RoleManager.sol";
import {MockHook} from "../src/mocks/hooks/MockHook.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockReporter} from "../src/mocks/MockReporter.sol";
import {IReporter} from "../src/reporter/IReporter.sol";
import {Registry} from "../src/registry/Registry.sol";

/**
 * @title ReportedStrategyTest
 * @notice Tests for ReportedStrategy
 */
contract ReportedStrategyTest is BaseFountfiTest {
    // Test contracts
    ReportedStrategy public strategy;
    tRWA public token;
    RoleManager public roleManager;
    MockHook public strategyHook;
    MockERC20 public daiToken;
    MockReporter public reporter;

    // Strategy parameters
    string constant TOKEN_NAME = "Test Reporter Token";
    string constant TOKEN_SYMBOL = "TREP";
    uint256 constant INITIAL_PRICE_PER_SHARE = 1e18; // 1 token per share (18 decimals)

    function setUp() public override {
        super.setUp();

        vm.startPrank(owner);

        // Deploy RoleManager first
        roleManager = new RoleManager();

        roleManager.grantRole(owner, roleManager.STRATEGY_OPERATOR());
        roleManager.grantRole(owner, roleManager.KYC_OPERATOR());

        // Deploy Registry with RoleManager address
        registry = new Registry(address(roleManager));

        // Initialize the registry for RoleManager.
        roleManager.initializeRegistry(address(registry));

        // Deploy test DAI token as the asset
        daiToken = new MockERC20("DAI Stablecoin", "DAI", 18);

        // Register the DAI token as allowed asset in the registry
        registry.setAsset(address(daiToken), 18);

        // Deploy hook
        strategyHook = new MockHook(true, "");

        // Deploy reporter with initial price per share
        reporter = new MockReporter(INITIAL_PRICE_PER_SHARE);

        // Deploy the strategy implementation
        ReportedStrategy strategyImpl = new ReportedStrategy();

        // Register the strategy implementation in the registry
        registry.setStrategy(address(strategyImpl), true);

        // Deploy strategy and token through the registry
        bytes memory initData = abi.encode(address(reporter));
        (address strategyAddr, address tokenAddr) =
            registry.deploy(address(strategyImpl), TOKEN_NAME, TOKEN_SYMBOL, address(daiToken), manager, initData);

        strategy = ReportedStrategy(payable(strategyAddr));
        token = tRWA(tokenAddr);

        vm.stopPrank();
        vm.startPrank(owner);
        // Fund the strategy with some DAI
        daiToken.mint(address(strategy), 1000 * 10 ** 18);

        vm.stopPrank();
    }

    function test_Initialization() public view {
        // Check that the strategy was initialized correctly
        assertEq(strategy.registry(), address(registry), "Registry should be set correctly");
        assertEq(strategy.manager(), manager, "Manager should be set correctly");
        assertEq(strategy.asset(), address(daiToken), "Asset should be set correctly");
        assertEq(address(token), strategy.sToken(), "Token should be set correctly");

        // Check reporter setup
        assertEq(address(strategy.reporter()), address(reporter), "Reporter should be set correctly");

        // Check that the token was initialized correctly
        assertEq(token.name(), TOKEN_NAME, "Token name should be set correctly");
        assertEq(token.symbol(), TOKEN_SYMBOL, "Token symbol should be set correctly");
        assertEq(address(token.asset()), address(daiToken), "Token asset should be set correctly");
        assertEq(address(token.strategy()), address(strategy), "Token strategy should be set correctly");
    }

    function test_InitWithInvalidReporter() public {
        vm.startPrank(owner);

        // Deploy a new strategy to test initialization with invalid reporter
        ReportedStrategy newStrategy = new ReportedStrategy();

        // Create init data with address(0) reporter
        bytes memory invalidInitData = abi.encode(address(0));

        // Test zero address for reporter
        vm.expectRevert(ReportedStrategy.InvalidReporter.selector);
        newStrategy.initialize(
            TOKEN_NAME, TOKEN_SYMBOL, address(roleManager), manager, address(daiToken), 18, invalidInitData
        );

        vm.stopPrank();
    }

    function test_Balance() public {
        // Check the balance calculation with initial setup (should be 0 since no tokens minted yet)
        uint256 bal = strategy.balance();
        assertEq(bal, 0, "Balance should be 0 when no tokens are minted");

        // Mint some tokens to create total supply by depositing assets
        vm.prank(owner);
        daiToken.mint(alice, 1000e18);
        vm.startPrank(alice);
        daiToken.approve(registry.conduit(), 1000e18);
        token.deposit(1000e18, alice); // This will mint tokens
        vm.stopPrank();

        // Now balance should be pricePerShare * totalSupply = 1e18 * 1000e18 / 1e18 = 1000e18
        bal = strategy.balance();
        assertEq(bal, 1000e18, "Balance should be price per share * total supply");

        // Update the reporter's price per share
        reporter.setValue(2e18); // 2 tokens per share

        // Check the updated balance: 2e18 * 1000e18 / 1e18 = 2000e18
        bal = strategy.balance();
        assertEq(bal, 2000e18, "Balance should reflect new price per share");
    }

    function test_SetReporter() public {
        vm.startPrank(manager);

        // Deploy a new reporter with a different price per share
        MockReporter newReporter = new MockReporter(5e18); // 5 tokens per share

        // Update the reporter
        strategy.setReporter(address(newReporter));

        // Check that the reporter was updated
        assertEq(address(strategy.reporter()), address(newReporter), "Reporter should be updated");

        // Mint some tokens to test the calculation by depositing
        vm.stopPrank();
        vm.prank(owner);
        daiToken.mint(alice, 1000e18);
        vm.startPrank(alice);
        daiToken.approve(registry.conduit(), 1000e18);
        token.deposit(1000e18, alice);
        vm.stopPrank();
        vm.startPrank(manager);

        // Check that the balance reflects the new reporter's price per share
        // 5e18 * 1000e18 / 1e18 = 5000e18
        uint256 bal = strategy.balance();
        assertEq(bal, 5000e18, "Balance should match the new reporter's price per share calculation");

        vm.stopPrank();
    }

    function test_SetReporterInvalidAddress() public {
        vm.startPrank(manager);

        // Try to set reporter to address(0)
        vm.expectRevert(ReportedStrategy.InvalidReporter.selector);
        strategy.setReporter(address(0));

        vm.stopPrank();
    }

    function test_SetReporterUnauthorized() public {
        vm.startPrank(alice);

        // Alice is not the manager
        vm.expectRevert(IStrategy.Unauthorized.selector);
        strategy.setReporter(address(0));

        vm.stopPrank();
    }

    function test_PricePerShare() public {
        // Test getting price per share
        uint256 pricePerShare = strategy.pricePerShare();
        assertEq(pricePerShare, INITIAL_PRICE_PER_SHARE, "Price per share should match initial value");

        // Update reporter and check again
        reporter.setValue(2e18);
        pricePerShare = strategy.pricePerShare();
        assertEq(pricePerShare, 2e18, "Price per share should reflect updated value");
    }

    function test_CalculateTotalAssets() public {
        // With no tokens minted, total assets should be 0
        uint256 totalAssets = strategy.balance();
        assertEq(totalAssets, 0, "Total assets should be 0 with no tokens");

        // Mint some tokens by depositing
        vm.prank(owner);
        daiToken.mint(alice, 500e18);
        vm.startPrank(alice);
        // Alice needs to approve the Conduit, not the tRWA token
        daiToken.approve(registry.conduit(), 500e18);
        token.deposit(500e18, alice);
        vm.stopPrank();

        // Calculate expected total assets: 1e18 * 500e18 / 1e18 = 500e18
        totalAssets = strategy.balance();
        assertEq(totalAssets, 500e18, "Total assets should equal price per share * total supply");

        // Update price per share and check again
        reporter.setValue(3e18);
        totalAssets = strategy.balance();
        assertEq(totalAssets, 1500e18, "Total assets should reflect new price per share");
    }

    function test_DepositWithdrawFlow() public {
        // Setup: Give Alice some DAI to deposit
        vm.prank(owner);
        daiToken.mint(alice, 2000e18);

        vm.startPrank(alice);
        daiToken.approve(registry.conduit(), 2000e18);

        // Initial state: no tokens minted, price per share = 1e18
        assertEq(token.totalSupply(), 0, "Initial total supply should be 0");
        assertEq(token.totalAssets(), 0, "Initial total assets should be 0");

        // Alice deposits 1000 DAI
        uint256 shares1 = token.deposit(1000e18, alice);

        // With price per share = 1e18, she should get 1000 shares
        assertEq(shares1, 1000e18, "Should get 1000 shares for 1000 DAI at 1:1 ratio");
        assertEq(token.totalSupply(), 1000e18, "Total supply should be 1000");

        assertEq(token.totalAssets(), 1000e18, "Total assets should be 1000 (1e18 * 1000e18 / 1e18)");

        // Update price per share to 1.5 (fund performance)
        vm.stopPrank();
        reporter.setValue(1.5e18);

        // Total assets should now reflect the new price
        assertEq(token.totalAssets(), 1500e18, "Total assets should be 1500 (1.5e18 * 1000e18 / 1e18)");

        // Alice deposits another 1000 DAI at the new price
        vm.startPrank(alice);
        uint256 shares2 = token.deposit(1000e18, alice);

        // At price 1.5, she should get 1000/1.5 = 666.67 shares (approximately)
        // The exact calculation depends on ERC4626 share pricing
        assertTrue(shares2 < 1000e18, "Should get fewer shares at higher price");
        assertTrue(shares2 > 600e18, "Should get more than 600 shares");

        uint256 totalSupplyAfter = token.totalSupply();

        uint256 totalAssetsAfter = token.totalAssets();

        // Total assets should be approximately 2500 (1.5 * new total supply)
        uint256 expectedAssets = (1.5e18 * totalSupplyAfter) / 1e18;
        assertApproxEqRel(
            totalAssetsAfter, expectedAssets, 0.01e18, "Total assets should match price per share calculation"
        );

        vm.stopPrank();
    }

    function test_ImmediateReflectionOfDeposits() public {
        // This test verifies that deposits are immediately reflected in totalAssets
        // even without oracle updates, which was the main problem we're solving

        vm.prank(owner);
        daiToken.mint(alice, 1500e18); // Need enough for both deposits

        vm.startPrank(alice);
        daiToken.approve(registry.conduit(), 1500e18); // Approve enough for both deposits

        // Before deposit
        uint256 assetsBefore = token.totalAssets();
        assertEq(assetsBefore, 0, "Assets should be 0 before deposit");

        // Deposit
        token.deposit(1000e18, alice);

        // After deposit - should immediately reflect the new assets
        // pricePerShare (1e18) * totalSupply (1000e18) = 1000e18
        uint256 assetsAfter = token.totalAssets();
        assertEq(assetsAfter, 1000e18, "Assets should immediately reflect deposit");

        // The key test: deposit again without oracle update
        token.deposit(500e18, alice);

        // Should immediately reflect the additional deposit
        // The second deposit gets 500 more shares (1:1 since totalAssets = totalSupply)
        // pricePerShare (1e18) * totalSupply (1500e18) = 1500e18
        uint256 assetsFinal = token.totalAssets();
        assertEq(assetsFinal, 1500e18, "Assets should immediately reflect second deposit");

        vm.stopPrank();
    }

    // Decimal permutation tests

    function deployStrategyWithDecimals(uint8 assetDecimals) internal returns (ReportedStrategy, tRWA, MockERC20) {
        vm.startPrank(owner);

        // Deploy test token as the asset with specified decimals
        MockERC20 assetToken = new MockERC20("Test Asset", "ASSET", assetDecimals);

        // Register the asset token in the registry
        registry.setAsset(address(assetToken), assetDecimals);

        // Deploy the strategy implementation
        ReportedStrategy strategyImpl = new ReportedStrategy();

        // Register the strategy implementation in the registry
        registry.setStrategy(address(strategyImpl), true);

        // Deploy strategy and token through the registry
        bytes memory initData = abi.encode(address(reporter));
        (address strategyAddr, address tokenAddr) =
            registry.deploy(address(strategyImpl), "Test Token", "TST", address(assetToken), manager, initData);

        vm.stopPrank();

        return (ReportedStrategy(payable(strategyAddr)), tRWA(tokenAddr), assetToken);
    }

    function test_Decimals_18Asset_18sToken() public {
        // Deploy with 18 decimal asset (standard case)
        (ReportedStrategy strat, tRWA tok, MockERC20 assetToken) = deployStrategyWithDecimals(18);

        // Verify decimals
        assertEq(assetToken.decimals(), 18, "Asset should have 18 decimals");
        assertEq(tok.decimals(), 18, "sToken should have 18 decimals");

        // Setup: Give Alice some assets to deposit
        vm.prank(owner);
        assetToken.mint(alice, 1000e18);

        vm.startPrank(alice);
        assetToken.approve(registry.conduit(), 1000e18);
        tok.deposit(1000e18, alice);
        vm.stopPrank();

        // Verify balance calculation
        // pricePerShare = 1e18, totalSupply = 1000e18, sTokenDecimals = 18, assetDecimals = 18
        // scalingFactor = 10^(18 + 18 - 18) = 10^18
        // balance = (1e18 * 1000e18) / 1e18 = 1000e18
        uint256 balance = strat.balance();
        assertEq(balance, 1000e18, "Balance should be 1000e18");

        // Update price and verify
        reporter.setValue(2e18); // 2x price
        balance = strat.balance();
        assertEq(balance, 2000e18, "Balance should be 2000e18 after price increase");
    }

    function test_Decimals_6Asset_18sToken() public {
        // Deploy with 6 decimal asset (USDC-like)
        (ReportedStrategy strat, tRWA tok, MockERC20 assetToken) = deployStrategyWithDecimals(6);

        // Verify decimals
        assertEq(assetToken.decimals(), 6, "Asset should have 6 decimals");
        assertEq(tok.decimals(), 18, "sToken should have 18 decimals");

        // Setup: Give Alice some assets to deposit (1000 USDC = 1000e6)
        vm.prank(owner);
        assetToken.mint(alice, 1000e6);

        vm.startPrank(alice);
        assetToken.approve(registry.conduit(), 1000e6);
        tok.deposit(1000e6, alice);
        vm.stopPrank();

        // Verify balance calculation
        // When depositing 1000e6, shares minted should be 1000e18 (due to decimal offset)
        assertEq(tok.totalSupply(), 1000e18, "Should have 1000e18 shares");

        // pricePerShare = 1e18, totalSupply = 1000e18, sTokenDecimals = 18, assetDecimals = 6
        // scalingFactor = 10^(18 + 18 - 6) = 10^30
        // balance = (1e18 * 1000e18) / 1e30 = 1e36 / 1e30 = 1e6 = 1000e6
        uint256 balance = strat.balance();
        assertEq(balance, 1000e6, "Balance should be 1000e6 (in 6 decimals)");

        // Update price and verify
        reporter.setValue(1.5e18); // 1.5x price
        balance = strat.balance();
        assertEq(balance, 1500e6, "Balance should be 1500e6 after price increase");
    }

    function test_Decimals_8Asset_18sToken() public {
        // Deploy with 8 decimal asset (WBTC-like)
        (ReportedStrategy strat, tRWA tok, MockERC20 assetToken) = deployStrategyWithDecimals(8);

        // Verify decimals
        assertEq(assetToken.decimals(), 8, "Asset should have 8 decimals");
        assertEq(tok.decimals(), 18, "sToken should have 18 decimals");

        // Setup: Give Alice some assets to deposit (10 WBTC = 10e8)
        vm.prank(owner);
        assetToken.mint(alice, 10e8);

        vm.startPrank(alice);
        assetToken.approve(registry.conduit(), 10e8);
        tok.deposit(10e8, alice);
        vm.stopPrank();

        // Verify shares minted
        assertEq(tok.totalSupply(), 10e18, "Should have 10e18 shares");

        // pricePerShare = 1e18, totalSupply = 10e18, sTokenDecimals = 18, assetDecimals = 8
        // scalingFactor = 10^(18 + 18 - 8) = 10^28
        // balance = (1e18 * 10e18) / 1e28 = 10e36 / 1e28 = 10e8
        uint256 balance = strat.balance();
        assertEq(balance, 10e8, "Balance should be 10e8 (in 8 decimals)");

        // Update price and verify
        reporter.setValue(3e18); // 3x price
        balance = strat.balance();
        assertEq(balance, 30e8, "Balance should be 30e8 after price increase");
    }

    function test_Decimals_2Asset_18sToken() public {
        // Deploy with 2 decimal asset (extreme low decimals)
        (ReportedStrategy strat, tRWA tok, MockERC20 assetToken) = deployStrategyWithDecimals(2);

        // Verify decimals
        assertEq(assetToken.decimals(), 2, "Asset should have 2 decimals");
        assertEq(tok.decimals(), 18, "sToken should have 18 decimals");

        // Setup: Give Alice some assets to deposit (100.00 = 10000 in 2 decimals)
        vm.prank(owner);
        assetToken.mint(alice, 10000);

        vm.startPrank(alice);
        assetToken.approve(registry.conduit(), 10000);
        tok.deposit(10000, alice);
        vm.stopPrank();

        // Verify shares minted (10000 * 10^16 = 100e18)
        assertEq(tok.totalSupply(), 100e18, "Should have 100e18 shares");

        // pricePerShare = 1e18, totalSupply = 100e18, sTokenDecimals = 18, assetDecimals = 2
        // scalingFactor = 10^(18 + 18 - 2) = 10^34
        // balance = (1e18 * 100e18) / 1e34 = 100e36 / 1e34 = 100e2 = 10000
        uint256 balance = strat.balance();
        assertEq(balance, 10000, "Balance should be 10000 (in 2 decimals)");

        // Update price and verify
        reporter.setValue(2.5e18); // 2.5x price
        balance = strat.balance();
        assertEq(balance, 25000, "Balance should be 25000 after price increase");
    }

    function test_Decimals_ComplexScenario_6Asset() public {
        // Complex scenario with multiple deposits and price changes
        (ReportedStrategy strat, tRWA tok, MockERC20 assetToken) = deployStrategyWithDecimals(6);

        // Initial deposit from Alice
        vm.prank(owner);
        assetToken.mint(alice, 1000e6);

        vm.startPrank(alice);
        assetToken.approve(registry.conduit(), 1000e6);
        tok.deposit(1000e6, alice);
        vm.stopPrank();

        // Initial balance check
        assertEq(strat.balance(), 1000e6, "Initial balance should be 1000e6");

        // Price increases to 1.2
        reporter.setValue(1.2e18);
        assertEq(strat.balance(), 1200e6, "Balance should be 1200e6 after price increase");

        // Bob deposits at new price
        vm.prank(owner);
        assetToken.mint(bob, 600e6);

        vm.startPrank(bob);
        assetToken.approve(registry.conduit(), 600e6);
        tok.deposit(600e6, bob);
        vm.stopPrank();

        // Bob should get approximately 500e18 shares (600e6 / 1.2)
        assertApproxEqRel(tok.balanceOf(bob), 500e18, 0.0001e18, "Bob should have approximately 500e18 shares");

        // Total supply should be approximately 1500e18
        assertApproxEqRel(tok.totalSupply(), 1500e18, 0.0001e18, "Total supply should be approximately 1500e18");

        // Total balance should be 1800e6 (1.2e18 * 1500e18 / 1e30)
        assertEq(strat.balance(), 1800e6, "Total balance should be 1800e6");
    }

    function test_Decimals_PricePerSharePrecision() public {
        // Test with very precise price per share values
        (ReportedStrategy strat, tRWA tok, MockERC20 assetToken) = deployStrategyWithDecimals(6);

        // Setup initial deposit
        vm.prank(owner);
        assetToken.mint(alice, 1000000e6); // 1M USDC

        vm.startPrank(alice);
        assetToken.approve(registry.conduit(), 1000000e6);
        tok.deposit(1000000e6, alice);
        vm.stopPrank();

        // Set a very precise price (1.123456789012345678)
        reporter.setValue(1123456789012345678);

        // Calculate expected balance
        // balance = (1123456789012345678 * 1000000e18) / 1e30
        // = 1123456789012345678000000e18 / 1e30
        // = 1123456789012345678e6
        // = 1123456.789012345678 * 1e6 (approximately 1,123,456.789012 USDC)
        uint256 balance = strat.balance();
        assertEq(balance, 1123456789012, "Balance should reflect precise price calculation");
    }

    function testFuzz_Decimals_Calculations(uint8 assetDecimals, uint256 depositAmount, uint256 pricePerShare) public {
        // Bound inputs to reasonable ranges
        assetDecimals = uint8(bound(assetDecimals, 1, 18));
        depositAmount = bound(depositAmount, 10, 10 ** uint256(assetDecimals) * 1000000);
        pricePerShare = bound(pricePerShare, 0.01e18, 1000e18);

        // Deploy strategy with fuzzed decimals
        (ReportedStrategy strat, tRWA tok, MockERC20 assetToken) = deployStrategyWithDecimals(assetDecimals);

        // Set the price
        reporter.setValue(pricePerShare);

        // Mint and deposit
        vm.prank(owner);
        assetToken.mint(alice, depositAmount);

        vm.startPrank(alice);
        assetToken.approve(registry.conduit(), depositAmount);
        tok.deposit(depositAmount, alice);
        vm.stopPrank();

        // Get the balance
        uint256 balance = strat.balance();

        // Verify the calculation manually
        uint256 totalSupply = tok.totalSupply();
        uint8 sTokenDecimals = tok.decimals();
        uint256 expectedBalance = (pricePerShare * totalSupply) / 10 ** (18 + sTokenDecimals - assetDecimals);

        assertEq(balance, expectedBalance, "Balance calculation should match expected");

        // Also verify that with price = 1e18, balance approximately equals deposit
        // (this tests the share minting logic)
        reporter.setValue(1e18);
        uint256 balanceAtParPrice = strat.balance();
        assertApproxEqRel(
            balanceAtParPrice, depositAmount, 0.001e18, "Balance at 1:1 price should approximately equal deposit"
        );
    }
}
