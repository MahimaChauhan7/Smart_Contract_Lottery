// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {Script, console} from "forge-std/Script.sol";

import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {Raffle} from "../src/Raffle.sol";
import {VRFCoordinatorV2_5Mock} from "chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {CodeConstants} from "./HelperConfig.s.sol";
contract CreateSubscription is Script {
    function createSubscription(address vrfCoordinator) public returns (unt64) {
        vm.startBroadcast();
        uint64 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription(); 
        vm.stopBroadcast();
        return subId;

    }
    function createSubscriptionUsingConfig() public returns (uint256) {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinator, 
            ,
            ,
            ,

        ) = helperConfig.getConfig(); 
        return createSubscription(vrfCoordinator);

        
    }
    function run() external returns(uint64) {
        return createSubscriptionUsingConfig();



    }

}
contract FundSubscription is Script, CodeConstants {
    uint256 public constant FUND_AMOUNT = 3 ether; 
    function FundSubscriptionUsingConfig() public {

        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address linkToken = helperConfig.getConfig().link;
        fundSubscription(vrfCoordinator, subscriptionId, linkToken);


    }
    function fundSubscription(
    address vrfCoordinator,
    uint256 subscriptionId,
    address linkToken
) public {
    console.log("Funding subscription: ", subscriptionId);
    console.log("Using vrfCoordinator: ", vrfCoordinator);
    console.log("On chainId: ", block.chainid);

    if (block.chainid == ETH_ANVIL_CHAIN_ID) {
        // Local Anvil -> use mock
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(
            subscriptionId,
            FUND_AMOUNT
        );
        vm.stopBroadcast();
    } else {
        // Real network -> fund with LINK
        console.log(LinkToken(linkToken).balanceOf(msg.sender));
        console.log(msg.sender);
        console.log(LinkToken(linkToken).balanceOf(address(this)));
        console.log(address(this));

        vm.startBroadcast();
        LinkToken(linkToken).transferAndCall(
            vrfCoordinator,
            (FUND_AMOUNT * 1000),
            abi.encode(subscriptionId)
        );
        vm.stopBroadcast();
    }
}

    function run() external {
        FundSubscriptionUsingConfig();

    }
}
contract AddConsumer is Script {
        function run() external {
        address raffle = DevOpsTools.get_most_recent_deployment("MyContract", block.chainid);
        addConsumerUsingConfig(raffle);
    }
    function addConsumer(address raffle, address vrfCoordinator, uint256 subscriptionId) public {
    console.log("Adding consumer contract: ", raffle);
    console.log("Using VRFCoordinator: ", vrfCoordinator);
    console.log("On chain id: ", block.chainid);

    vm.startBroadcast();
    VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subscriptionId, raffle);
    vm.stopBroadcast();
}

function addConsumerUsingConfig(address raffle) public {
    HelperConfig helperConfig = new HelperConfig();
    (
        ,
        ,
        address vrfCoordinator,
        ,
        uint256 subscriptionId,
        ,
    ) = helperConfig.getConfig();

    addConsumer(raffle, vrfCoordinator, subscriptionId);
}

function run() external {
    address raffle = DevOpsTools.get_most_recent_deployment("MyContract", block.chainid);
    addConsumerUsingConfig(raffle);
}

    
}