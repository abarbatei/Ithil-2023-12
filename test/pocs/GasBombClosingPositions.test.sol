// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.18;

import { Test } from "forge-std/Test.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20PresetMinterPauser } from "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import { IVault } from "../../src/interfaces/IVault.sol";
import { IService } from "../../src/interfaces/IService.sol";
import { IManager, Manager } from "../../src/Manager.sol";
import { Ithil } from "../../src/Ithil.sol";
import { CallOption } from "../../src/services/credit/CallOption.sol";
import { GeneralMath } from "../helpers/GeneralMath.sol";
import { BaseIntegrationServiceTest } from "../services/BaseIntegrationServiceTest.sol";
import { OrderHelper } from "../helpers/OrderHelper.sol";

contract CallOptionPocTest is BaseIntegrationServiceTest {
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

    function testOverloadPosition() public {
        // run as: forge test --match-test testOverloadPosition -vv --gas-report
        // to see gass consumption
        uint256 daiLoan = 1e18;
        uint256 MAX_COLLATERAL = 4000;
        address[] memory collateralTokensWall = new address[](MAX_COLLATERAL);
        collateralTokensWall[0] = manager.vaults(loanTokens[0]);
        collateralTokensWall[1] = address(ithil);

        uint256[] memory loans = new uint256[](loanLength);
        loans[0] = daiLoan;

        // allow for 2 slots to cover the case of the call option
        IService.ItemType[] memory itemTypes = new IService.ItemType[](2);
        itemTypes[0] = IService.ItemType.ERC20;
        itemTypes[1] = IService.ItemType.ERC20;

        uint256[] memory collateralAmounts = new uint256[](MAX_COLLATERAL);
        collateralAmounts[0] = 0;

        deal(address(loanTokens[0]), address(this), 1e25);

        IService.Order memory order = OrderHelper.createAdvancedOrder(
                loanTokens,
                loans,
                new uint256[](1),
                itemTypes,
                collateralTokensWall,
                collateralAmounts,
                block.timestamp,
                abi.encode(11)
            );


        service.open(order);

        vm.warp(block.timestamp + 12 * 30 * 86500);

        service.close(0, abi.encode(1e18));
    }
}
