// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.18;

import { IERC20, IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { Test, console } from "forge-std/Test.sol";
import { IVault, Vault } from "../../src/Vault.sol";
import { GeneralMath } from "../helpers/GeneralMath.sol";
import { PermitToken } from "../helpers/PermitToken.sol";


contract VaultPoCTest is Test {
    using Math for uint256;
    using GeneralMath for uint256;

    Vault internal immutable vault;
    PermitToken internal immutable token;
    address internal immutable tokenSink;
    address internal immutable notOwner;
    address internal immutable anyAddress;
    address internal immutable depositor;
    address internal immutable receiver;
    address internal immutable borrower;
    address internal immutable repayer;

    constructor() {
        token = new PermitToken("test", "TEST");
        vault = new Vault(IERC20Metadata(address(token)));
        tokenSink = makeAddr("Sink");
        notOwner = makeAddr("Not Owner");
        anyAddress = makeAddr("Any Address");
        depositor = makeAddr("Depositor");
        receiver = makeAddr("Receiver");
        repayer = makeAddr("Repayer");
        borrower = makeAddr("Borrower");
    }

    function setUp() public {
        token.mint(tokenSink, type(uint256).max);
        token.approve(address(vault), type(uint256).max);
    }

    function testFeeUnlockTimeChangesProfit() public {
        // initial setups
        uint256 initialFeeUnlockTime = 4 days;
        uint256 totalSupply = 100 ether;

        vault.setFeeUnlockTime(initialFeeUnlockTime);

        deal(address(token), depositor, totalSupply);
        vm.startPrank(depositor);
        token.approve(address(vault), totalSupply);
        vault.deposit(totalSupply, receiver);
        vm.stopPrank();

        uint256 initialCurrentProfits = 25 ether;        
        uint256 initialCurrentLosses = 30 ether;
        deal(address(token), repayer, type(uint256).max);

        vm.prank(repayer);
        token.approve(address(vault), type(uint256).max);
        vault.repay(initialCurrentProfits, 0, repayer);
        
        vault.borrow(initialCurrentLosses, initialCurrentLosses, borrower);
        vault.repay(0, initialCurrentLosses, repayer);

        // profits and losses accumulated up to this time
        uint256 currentProfits = vault.currentProfits();
        uint256 currentLosses = vault.currentLosses();
        
        // forward 1 day into the future
        vm.warp(block.timestamp + 1 days);

        // set setFeeUnlockTime 1 day less then initial fee unlock time
        vault.setFeeUnlockTime(initialFeeUnlockTime - 1 days);
        
        assertEq(currentProfits, vault.currentProfits());
        assertEq(currentLosses, vault.currentLosses());

        // taka a snapshot of the current environment
        uint256 snapshot = vm.snapshot();

        // forward one more day
        vm.warp(block.timestamp + 1 days);
        // calculate current profits and losses now
        vault.repay(0, 0, borrower);

        uint256 profitsWhenUnlockTimeNotAccountedFor = vault.currentProfits();
        uint256 lossesWhenUnlockTimeNotAccountedFor = vault.currentLosses();

        // go back to exactly after we updated the fee unlock time
        vm.revertTo(snapshot);

        // directly updated profits and losses to take into account new time, no waiting
        vault.repay(0, 0, borrower);

        // forward one more day, as in the first case
        vm.warp(block.timestamp + 1 days);
        // calculate current profits and losses now
        vault.repay(0, 0, borrower);

        uint256 profitsWhenUnlockTimeAccountedFor = vault.currentProfits();
        uint256 lossesWhenUnlockTimeAccountedFor = vault.currentLosses();

        // indicated that in the second, correct case, profits and losses are greater
        assertGt(profitsWhenUnlockTimeAccountedFor, profitsWhenUnlockTimeNotAccountedFor);
        assertGt(lossesWhenUnlockTimeAccountedFor, lossesWhenUnlockTimeNotAccountedFor);
    }
}
