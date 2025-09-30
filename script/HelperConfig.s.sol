// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {LinkToken} from "../mocks/LinkToken.sol";
import {Script, console2} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

error HelperConfig__InvalidChainId();

abstract contract CodeConstants {
    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
}

// Mock constants
uint96 constant MOCK_BASE_FEE = 1e17;
uint96 constant MOCK_GAS_PRICE_LINK = 1e9;
int256 constant MOCK_WEI_PER_UNIT_LINK = 4e15;
address constant FOUNDRY_DEFAULT_SENDER = address(0x1234);
uint256 constant DEFAULT_ANVIL_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

contract HelperConfig is CodeConstants, Script {
    struct NetworkConfig {
        uint256 raffleEntranceFee;
        uint256 automationUpdateInterval;
        address vrfCoordinatorV2_5;
        bytes32 gasLane;
        uint32 callbackGasLimit;
        uint64 subscriptionId;
        address link;
        uint256 deployerKey;
    }

    mapping(uint256 => NetworkConfig) public networkConfigs;
    NetworkConfig public localNetworkConfig;

    constructor() {
        // Don't initialize Sepolia config in constructor to avoid env var errors during tests
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            raffleEntranceFee: 0.01 ether,
            automationUpdateInterval: 30,
            vrfCoordinatorV2_5: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            callbackGasLimit: 500000,
            subscriptionId: 0,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            deployerKey: vm.envUint("SEPOLIA_PRIVATE_KEY")
        });
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (chainId == ETH_SEPOLIA_CHAIN_ID) {
            return getSepoliaEthConfig();
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        // Check if we already have a local network config
        if (localNetworkConfig.vrfCoordinatorV2_5 != address(0)) {
            return localNetworkConfig;
        }

        // Deploy mocks
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorV2_5Mock =
            new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK, MOCK_WEI_PER_UNIT_LINK);
        LinkToken link = new LinkToken();
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            raffleEntranceFee: 0.01 ether,
            automationUpdateInterval: 30, // 30 seconds
            vrfCoordinatorV2_5: address(vrfCoordinatorV2_5Mock),
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            callbackGasLimit: 500000, // 500,000 gas
            subscriptionId: 0, // If left as 0, our scripts will create one!
            link: address(link),
            deployerKey: DEFAULT_ANVIL_KEY
        });

        return localNetworkConfig;
    }
}
