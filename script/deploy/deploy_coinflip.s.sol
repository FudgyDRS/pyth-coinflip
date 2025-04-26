// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {Coinflip} from "@/Coinflip.sol";

contract DeployCoinflipScript is Script {
    Coinflip public coinflip;
    address constant ENTROPY = 0x36825bf3Fbdf5a29E2d5148bfe7Dcf7B5639e320;

    function setUp() public {}

    function run() public {
        

        vm.startBroadcast();

        coinflip = new Coinflip(ENTROPY);

        vm.stopBroadcast();
    }
}
