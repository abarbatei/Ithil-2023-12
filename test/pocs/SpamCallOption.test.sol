// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.18;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IService } from "../../src/interfaces/IService.sol";
import { Ithil } from "../../src/Ithil.sol";
import { CallOption } from "../../src/services/credit/CallOption.sol";
import { GeneralMath } from "../helpers/GeneralMath.sol";
import { BaseIntegrationServiceTest } from "../services/BaseIntegrationServiceTest.sol";
import { OrderHelper } from "../helpers/OrderHelper.sol";

contract SpamCallOptionTest is BaseIntegrationServiceTest {
    using GeneralMath for uint256;

    CallOption internal immutable service;
    Ithil internal immutable ithil;
    address internal constant weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    string internal constant rpcUrl = "ARBITRUM_RPC_URL";
    uint256 internal constant blockNumber = 119065280;

    uint64[] internal _rewards;

    constructor() BaseIntegrationServiceTest(rpcUrl, blockNumber) {
        _rewards = new uint64[](12);
        _rewards[0] = 1059463094359295265;
        _rewards[1] = 1122462048309372981;
        _rewards[2] = 1189207115002721067;
        _rewards[3] = 1259921049894873165;
        _rewards[4] = 1334839854170034365;
        _rewards[5] = 1414213562373095049;
        _rewards[6] = 1498307076876681499;
        _rewards[7] = 1587401051968199475;
        _rewards[8] = 1681792830507429086;
        _rewards[9] = 1781797436280678609;
        _rewards[10] = 1887748625363386993;
        _rewards[11] = 2000000000000000000;
        vm.startPrank(admin);
        ithil = new Ithil(admin);
        loanLength = 1;
        loanTokens = new address[](loanLength);
        collateralTokens = new address[](2);
        loanTokens[0] = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1; // DAI
        whales[loanTokens[0]] = 0x252cd7185dB7C3689a571096D5B57D45681aA080;
        vm.stopPrank();
        vm.prank(whales[loanTokens[0]]);
        IERC20(loanTokens[0]).transfer(admin, 1);
        vm.startPrank(admin);
        IERC20(loanTokens[0]).approve(address(manager), 1);
        manager.create(loanTokens[0]);
        service = new CallOption(address(manager), address(ithil), 4e17, 86400 * 30, 86400 * 30, 0, loanTokens[0]);
        serviceAddress = address(service);
        ithil.approve(serviceAddress, 1e25);
        service.allocateIthil(1e25);
        vm.stopPrank();
    }


    function testNegatePriceDiscount() public {
        collateralTokens[0] = manager.vaults(loanTokens[0]);
        collateralTokens[1] = address(ithil);
        uint256 initialPrice = service.currentPrice();

        // This bumps the price
        IService.Order memory normalOrder = _openOrder1ForCredit(100 ether, 0, block.timestamp, abi.encode(7));
        service.open(normalOrder);
        
        // take a snapshot before starting spamming 1 WEI open orders
        uint256 snapshot = vm.snapshot();

        // for roughly 3 hours, every 12 seconds a 1 WEI buy is done
        uint256 spamTime = 3 hours;
        uint256 blocks = spamTime / 12 ;
        for (uint256 i = 0; i < blocks; i++) {
            IService.Order memory oneWeiOrder = _openOrder1ForCredit(1, 0, block.timestamp, abi.encode(7));        
            service.open(oneWeiOrder);
            vm.warp(block.timestamp + 12);
        }

        // store the price after doing this
        uint256 priceAfterOneHourSpam = service.currentPrice();

        // revert to before doing this
        vm.revertTo(snapshot);

        // fast forward to the present and get price
        vm.warp(block.timestamp + blocks * 12);
        uint256 priceAfterOneHourSimple = service.currentPrice();

        // compare that the price with orders spam is larger then the one without any intermediary orders
        assertGt(priceAfterOneHourSpam, priceAfterOneHourSimple);
    }
}
