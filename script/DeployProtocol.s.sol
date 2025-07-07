// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import {Registry} from "../src/registry/Registry.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {KycRulesHook} from "../src/hooks/KycRulesHook.sol";
import {PriceOracleReporter} from "../src/reporter/PriceOracleReporter.sol";
import {ReportedStrategy} from "../src/strategy/ReportedStrategy.sol";
import {GatedMintReportedStrategy} from "../src/strategy/GatedMintRWAStrategy.sol";
import {ManagedWithdrawReportedStrategy} from "../src/strategy/ManagedWithdrawRWAStrategy.sol";
import {RoleManager} from "../src/auth/RoleManager.sol";
import {Conduit} from "../src/conduit/Conduit.sol";

contract DeployProtocolScript is Script {
    // Management addresses
    address public constant MANAGER_1 = 0x91C64d8D530c494B65A7ae58B8534Ac5A05A3d43;

    // Storage for deployed contract addresses
    RoleManager public roleManager;
    MockERC20 public usdToken;
    Registry public registry;
    KycRulesHook public kycRulesHook;
    PriceOracleReporter public priceOracle;
    ManagedWithdrawReportedStrategy public strategyImplementation;
    Conduit public conduit;

    function setUp() public {}

    function run() public {
        // Use the private key directly from the command line parameter
        address deployer = msg.sender;
        console.log("Deploying from:", deployer);

        vm.startBroadcast();

        // Deploy core infrastructure
        deployInfrastructure(deployer);

        // Log all deployed contracts
        logDeployedContracts();

        vm.stopBroadcast();
    }

    function deployInfrastructure(address deployer) internal {
        // Deploy Role Manager first for better access control
        roleManager = new RoleManager();

        // Grant admin roles to manager addresses
        grantRolesToManagers();

        console.log("RoleManager deployed and roles configured.");

        console.log("Mock USD Token deployed and minted to managers.");

        // Deploy Registry with role manager
        registry = new Registry(address(roleManager));
        console.log("Registry deployed.");

        conduit = Conduit(registry.conduit());

        // Link registry to role manager
        roleManager.initializeRegistry(address(registry));

        // Deploy mock USD token
        usdToken = new MockERC20("Mock USD", "USDC", 6);

        // Mint tokens to various addresses for testing
        usdToken.mint(deployer, 50_000_000_000_000_000_000); // 50MM USDC with 6 decimals
        usdToken.mint(MANAGER_1, 50_000_000_000_000_000_000); // 50MM USDC with 6 decimals
        usdToken.mint(0x36Abd7ABde32E292707D81B225eA34a15CD92F6C, 50_000_000_000_000_000_000); // 50MM USDC with 6 decimals
        usdToken.mint(0x75BbFf2206b6Ad50786Ee3ce8A81eDb72f3e381b, 50_000_000_000_000_000_000); // 50MM USDC with 6 decimals
        usdToken.mint(0x76F2DAD4741CB0f4C8C56361d8cF5E05Bc01Bf28, 50_000_000_000_000_000_000); // 50MM USDC with 6 decimals

        // Allow Mock USD token as an asset
        registry.setAsset(address(usdToken), 6);

        address USDC_ON_BASE = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
        registry.setAsset(USDC_ON_BASE, 6); // Allow USDC on Base

        address CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
        registry.setAsset(CBBTC, 8); // Allow CBBTC on Base

        address WBTC = 0x0555E30da8f98308EdB960aa94C0Db47230d2B9c;
        registry.setAsset(WBTC, 8); // Allow WBTC on Base

        // Deploy KYC Rules Hook with role manager
        kycRulesHook = new KycRulesHook(address(roleManager));
        console.log("KYC Rules Hook deployed.");

        // Add this hook to allowed hooks in registry
        registry.setHook(address(kycRulesHook), true);

        // Allow addresses in KYC rules
        kycRulesHook.allow(deployer);
        kycRulesHook.allow(MANAGER_1);
        kycRulesHook.allow(0x36Abd7ABde32E292707D81B225eA34a15CD92F6C);
        kycRulesHook.allow(0x75BbFf2206b6Ad50786Ee3ce8A81eDb72f3e381b);
        kycRulesHook.allow(0x76F2DAD4741CB0f4C8C56361d8cF5E05Bc01Bf28);
        console.log("Deployers allowed in KYC rules.");

        // Deploy Price Oracle Reporter with initial price of 1 USD
        uint256 initialPrice = 1e18; // $1.00 with 18 decimals
        priceOracle = new PriceOracleReporter(initialPrice, MANAGER_1, 100, 3600); // 1% max change per hour
        priceOracle.setUpdater(MANAGER_1, true);
        console.log("Price Oracle Reporter deployed.");

        // Deploy ManagedWithdrawReportedStrategy implementation to be used as a template
        strategyImplementation = new ManagedWithdrawReportedStrategy();
        console.log("ManagedWithdrawReportedStrategy implementation deployed.");

        // Register both strategy implementations in the registry
        registry.setStrategy(address(strategyImplementation), true);
        console.log("Registry configured with strategy implementations.");
    }

    function grantRolesToManagers() internal {
        // Protocol admins
        roleManager.grantRole(MANAGER_1, roleManager.PROTOCOL_ADMIN());

        // Strategy roles
        roleManager.grantRole(MANAGER_1, roleManager.STRATEGY_ADMIN());
        roleManager.grantRole(MANAGER_1, roleManager.STRATEGY_OPERATOR());

        // KYC roles
        roleManager.grantRole(MANAGER_1, roleManager.RULES_ADMIN());
        roleManager.grantRole(MANAGER_1, roleManager.KYC_OPERATOR());
    }

    function logDeployedContracts() internal view {
        // Log deployed contract addresses
        console.log("\nDeployed contracts:");
        console.log("Role Manager:", address(roleManager));
        console.log("Mock USD Token:", address(usdToken));
        console.log("Registry:", address(registry));
        console.log("Conduit:", address(conduit));
        console.log("KYC Rules Hook:", address(kycRulesHook));
        console.log("Price Oracle Reporter:", address(priceOracle));
        console.log("Strategy Implementation:", address(strategyImplementation));
    }
}
