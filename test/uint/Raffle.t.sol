// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18; 
import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol"; 
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol"; 
import {vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "chainlink/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol"; 


contract RaffleTest is Test {
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 public entranceFee;
    uint256 public interval;
    address public vrfCoordinator;
    bytes32 public gasLane;
    uint32 public callbackGasLimit;
    uint256 public subscriptionId;
    address linkToken;
    event EnteredRaffle(address indexed player);
    modifier raffleEntredAndTimePassed() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}(); 
        vm.wrap(block.timestamp + interval +1);
        vm.roll(block.number +1);
    }

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle(); 
        (raffle, helperConfig) = deployer.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig(); 
        entranceFee = config.raffleEntranceFee; 
        interval = config.automationUpdateInterval; 
        vrfCoordinator = config.vrfCoordinatorV2_5; 
        gasLane = config.gasLane; 
        callbackGasLimit = config.callbackGasLimit; 
        subscriptionId = config.subscriptionId; 
        inkToken = LinkToken(config.linkToken);
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE); 
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }
    function testRaffleRevertWhenYouDontPayEnough() public {
        vm.prank(PLAYER);

        vm.expectRevert(Raffle.Raffle_NotEnoughEthSent.selector); 
        raffle.enterRaffle(); 
    }
    function testEmitsEventOnEntrance() public {
        // Arrange 
        vm.prank(PLAYER);
        // Act/ Asser 
        vm.expectEmit(true, false, false, false, address(raffle)); 
        emit EnteredRaffle(PLAYER); 
        raffle.enterRaffle{value: entranceFee}();
    }
    function testDontAllowPlayersToEnterWhileRafflesCalculating() public {
        // Arrange 
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1); 
        vm.roll(block.number + 1); 
        raffle.performUpkeep("");
        //Act / Assert 
        vm.expectRevert(Raffle_RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }
    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        //Arrange 
        vm.warp(block.timestamp + automationUpdateInterval + 1); 
        vm.roll(block.number + 1); 
        
        //Act 
        (bool upkeepNeeded,) = raffle.checkUPkeep("");
        // Assert 
        assert(!upkeepNeeded);

    }
    function testCheckUpkeepReturnsFalseIfRaffleIsntOpen() public {
    // Arrange
    vm.prank(PLAYER);
    raffle.enterRaffle{value: raffleEntranceFee}();

    vm.warp(block.timestamp + automationUpdateInterval + 1);
    vm.roll(block.number + 1);

    raffle.performUpkeep("");

    Raffle.RaffleState raffleState = raffle.getRaffleState();

    // Act
    (bool upkeepNeeded,) = raffle.checkUpkeep("");

    // Assert
    assert(raffleState == Raffle.RaffleState.CALCULATING);
    assert(upkeepNeeded == false);
}
function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
    // Arrange
    vm.prank(PLAYER);
    raffle.enterRaffle{value: entranceFee}();
    vm.warp(block.timestamp + interval + 1);
    vm.roll(block.number + 1);

    // Act / Assert
    // It doesnt revert
    vm.expectRevert(
        abi.encodeWithSelector(CustomError.selector, 1, 2)
    );
    raffle.performUpkeep("");
}
function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public raffleEntredAndTimePassed{
    //Act 
    vm.recordLogs();
    raffle.performUpkeep(""); //emit requestId 
    Vm.log[] memory entries = vm.getRecordedLogs();
    byte32 requestId = entries[1].topics[1]; 
    //Assert 
    Raffle.RaffleState raffleState = raffle.getRaffleState(); 
    // requestId = raffle.getLastRequestId(); 
    assert(uint256(requestId) > 0);
    assert(uint(raffleState ==1 ));


}
function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep() public raffleEntredAndTimePassed {
    //Arrange 
    //Act 
    //Assert 
    vm.expectRevert("nonexistent request"); 
    //vm.mockCall could be used here...
    VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
        0, 
        address(raffle)
    );
}
function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId)
    public
    raffleEntredAndTimePassed
{
    // Arrange
    // Act / Assert
    vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
    // vm.mockCall could be used here...
    VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
        randomRequestId,
        address(raffle)
    );
}

function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney() public raffleEnteredAndTimePassed {
    // Arrange
    uint256 additionalEntrants = 3;
    uint256 startingIndex = 1;

    // Add extra players into the raffle
    for (uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++) {
        address player = address(uint160(i));
        hoax(player, STARTING_USER_BALANCE); // fund + prank
        raffle.enterRaffle{value: entranceFee}();
    }

    // Total prize pool = entrance fee * total players
    uint256 prize = entranceFee * (additionalEntrants + 1);

    // Record expected winner’s starting balance
    uint256 winnerStartingBalance = expectedWinner.balance;

    // Act
    vm.recordLogs();
    raffle.performUpkeep(""); // emits requestId
    Vm.Log[] memory entries = vm.getRecordedLogs();
    bytes32 requestId = entries[1].topics[1];

    // Simulate Chainlink VRF fulfilling randomness
    VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
        uint256(requestId),
        address(raffle)
    );

    // Assert
    address recentWinner = raffle.getRecentWinner();
    Raffle.RaffleState raffleState = raffle.getRaffleState();
    uint256 winnerBalance = recentWinner.balance;
    uint256 endingTimeStamp = raffle.getLastTimeStamp();

    assert(expectedWinner == recentWinner);                     // winner picked correctly
    assert(uint256(raffleState) == 0);                          // raffle reset (OPEN)
    assert(winnerBalance == winnerStartingBalance + prize);     // winner got prize
    assert(endingTimeStamp > startingTimeStamp);                // timestamp updated
}





}



