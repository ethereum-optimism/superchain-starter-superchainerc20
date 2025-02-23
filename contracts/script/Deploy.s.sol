// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";
import {ICreateX} from "createx/ICreateX.sol";

import {DeployUtils} from "../libraries/DeployUtils.sol";
<<<<<<< HEAD
import {InitialSupplySuperchainERC20} from "../src/InitialSupplySuperchainERC20.sol";
=======
import {CrossChainCounter} from "../src/CrossChainCounter.sol";
>>>>>>> upstream/main

// Example forge script for deploying as an alternative to sup: super-cli (https://github.com/ethereum-optimism/super-cli)
contract Deploy is Script {
    /// @notice Array of RPC URLs to deploy to, deploy to supersim 901 and 902 by default.
    string[] private rpcUrls = ["http://localhost:9545", "http://localhost:9546"];

    /// @notice Modifier that wraps a function in broadcasting.
    modifier broadcast() {
        vm.startBroadcast(msg.sender);
        _;
        vm.stopBroadcast();
    }

    function run() public {
        for (uint256 i = 0; i < rpcUrls.length; i++) {
            string memory rpcUrl = rpcUrls[i];

            console.log("Deploying to RPC: ", rpcUrl);
            vm.createSelectFork(rpcUrl);
<<<<<<< HEAD
            deployInitialSupplySuperchainERC20Contract();
        }
    }

    function deployInitialSupplySuperchainERC20Contract() public broadcast returns (address addr_) {
        bytes memory initCode = abi.encodePacked(
            type(InitialSupplySuperchainERC20).creationCode,
            abi.encode(msg.sender, "Test", "TEST", 18, 1000, block.chainid)
        );
        addr_ = DeployUtils.deployContract("InitialSupplySuperchainERC20", _implSalt(), initCode);
=======
            deployCrossChainCounterContract();
        }
    }

    function deployCrossChainCounterContract() public broadcast returns (address addr_) {
        bytes memory initCode = abi.encodePacked(type(CrossChainCounter).creationCode);
        addr_ = DeployUtils.deployContract("CrossChainCounter", _implSalt(), initCode);
>>>>>>> upstream/main
    }

    /// @notice The CREATE2 salt to be used when deploying a contract.
    function _implSalt() internal view returns (bytes32) {
        return keccak256(abi.encodePacked(vm.envOr("DEPLOY_SALT", string("ethers phoenix"))));
    }
}
