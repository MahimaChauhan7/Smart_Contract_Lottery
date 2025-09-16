// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription} from "./Interaction.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interaction.s.sol";


contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig(); 
        (
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit

        ) = helperConfig.getConfig();
        if(subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription(); 
            subcriptionId = createSubscription.createSubscription(vrfCoordinator);
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(vrfCoordinator, subscriptionId, link);


        }
        vm.startBroadcast();
        Raffle raffle = new Raffle(
            entranceFee, 
            interval, 
            vrfCoordinator, 
            gasLane, 
            subscriptionId, 
            callbackGasLimit
        );
        vm.stopBroadcast();
        return (raffle, helperConfig); 

    }
       
} 
