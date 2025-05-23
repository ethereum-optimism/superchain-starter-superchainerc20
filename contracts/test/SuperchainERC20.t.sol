// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Testing utilities
import {Test} from "forge-std/Test.sol";

// Libraries
import {PredeployAddresses} from "@interop-lib/libraries/PredeployAddresses.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Unauthorized} from "@interop-lib/libraries/errors/CommonErrors.sol";

// Target contract
import {SuperchainERC20} from "@interop-lib/SuperchainERC20.sol";
import {IERC7802} from "@interop-lib/interfaces/IERC7802.sol";
import {InitialSupplySuperchainERC20} from "../src/InitialSupplySuperchainERC20.sol";

/// @title SuperchainERC20Test
/// @notice Contract for testing the SuperchainERC20 contract.
contract SuperchainERC20Test is Test {
    address internal constant ZERO_ADDRESS = address(0);
    address internal constant SUPERCHAIN_TOKEN_BRIDGE = PredeployAddresses.SUPERCHAIN_TOKEN_BRIDGE;
    address internal constant MESSENGER = PredeployAddresses.L2_TO_L2_CROSS_DOMAIN_MESSENGER;

    uint256 internal constant INITIAL_SUPPLY = 1000000000 ether;

    SuperchainERC20 public superchainERC20;

    /// @notice Sets up the test suite.
    function setUp() public {
        superchainERC20 =
            new InitialSupplySuperchainERC20(address(this), "Test", "TEST", 18, INITIAL_SUPPLY, block.chainid);
    }

    /// @notice Helper function to setup a mock and expect a call to it.
    function _mockAndExpect(address _receiver, bytes memory _calldata, bytes memory _returned) internal {
        vm.mockCall(_receiver, _calldata, _returned);
        vm.expectCall(_receiver, _calldata);
    }

    /// @notice Tests the `mint` function reverts when the caller is not the bridge.
    function testFuzz_crosschainMint_callerNotBridge_reverts(address _caller, address _to, uint256 _amount) public {
        // Ensure the caller is not the bridge
        vm.assume(_caller != SUPERCHAIN_TOKEN_BRIDGE);

        // Expect the revert with `Unauthorized` selector
        vm.expectRevert(Unauthorized.selector);

        // Call the `mint` function with the non-bridge caller
        vm.prank(_caller);
        superchainERC20.crosschainMint(_to, _amount);
    }

    /// @notice Tests the `mint` succeeds and emits the `Mint` event.
    function testFuzz_crosschainMint_succeeds(address _to, uint256 _amount) public {
        // Ensure `_to` is not the zero address and amount is reasonable
        vm.assume(_to != ZERO_ADDRESS);
        vm.assume(_amount <= type(uint256).max - INITIAL_SUPPLY);

        // Get the total supply and balance of `_to` before the mint to compare later on the assertions
        uint256 _totalSupplyBefore = superchainERC20.totalSupply();
        uint256 _toBalanceBefore = superchainERC20.balanceOf(_to);

        // Look for the emit of the `Transfer` event
        vm.expectEmit(address(superchainERC20));
        emit IERC20.Transfer(ZERO_ADDRESS, _to, _amount);

        // Look for the emit of the `CrosschainMint` event
        vm.expectEmit(address(superchainERC20));
        emit IERC7802.CrosschainMint(_to, _amount, SUPERCHAIN_TOKEN_BRIDGE);

        // Call the `mint` function with the bridge caller
        vm.prank(SUPERCHAIN_TOKEN_BRIDGE);
        superchainERC20.crosschainMint(_to, _amount);

        // Check the total supply and balance of `_to` after the mint were updated correctly
        assertEq(superchainERC20.totalSupply(), _totalSupplyBefore + _amount);
        assertEq(superchainERC20.balanceOf(_to), _toBalanceBefore + _amount);
    }

    /// @notice Tests the `burn` function reverts when the caller is not the bridge.
    function testFuzz_crosschainBurn_callerNotBridge_reverts(address _caller, address _from, uint256 _amount) public {
        // Ensure the caller is not the bridge
        vm.assume(_caller != SUPERCHAIN_TOKEN_BRIDGE);

        // Expect the revert with `Unauthorized` selector
        vm.expectRevert(Unauthorized.selector);

        // Call the `burn` function with the non-bridge caller
        vm.prank(_caller);
        superchainERC20.crosschainBurn(_from, _amount);
    }

    /// @notice Tests the `burn` burns the amount and emits the `CrosschainBurn` event.
    function testFuzz_crosschainBurn_succeeds(address _from, uint256 _amount) public {
        // Ensure `_from` is not the zero address and not the initial owner
        vm.assume(_from != ZERO_ADDRESS);
        vm.assume(_from != address(this));
        // Ensure amount is reasonable
        vm.assume(_amount <= type(uint256).max - INITIAL_SUPPLY);

        // Mint some tokens to `_from` so then they can be burned
        vm.prank(SUPERCHAIN_TOKEN_BRIDGE);
        superchainERC20.crosschainMint(_from, _amount);

        // Get the total supply and balance of `_from` before the burn to compare later on the assertions
        uint256 _totalSupplyBefore = superchainERC20.totalSupply();
        uint256 _fromBalanceBefore = superchainERC20.balanceOf(_from);

        // Look for the emit of the `Transfer` event
        vm.expectEmit(address(superchainERC20));
        emit IERC20.Transfer(_from, ZERO_ADDRESS, _amount);

        // Look for the emit of the `CrosschainBurn` event
        vm.expectEmit(address(superchainERC20));
        emit IERC7802.CrosschainBurn(_from, _amount, SUPERCHAIN_TOKEN_BRIDGE);

        // Call the `burn` function with the bridge caller
        vm.prank(SUPERCHAIN_TOKEN_BRIDGE);
        superchainERC20.crosschainBurn(_from, _amount);

        // Check the total supply and balance of `_from` after the burn were updated correctly
        assertEq(superchainERC20.totalSupply(), _totalSupplyBefore - _amount);
        assertEq(superchainERC20.balanceOf(_from), _fromBalanceBefore - _amount);
    }
}
