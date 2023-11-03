// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import {ERC20PresetMinterPauser} from "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {MockAxelarGateway} from "../../../../src/test/root/MockAxelarGateway.sol";
import {MockAxelarGasService} from "../../../../src/test/root/MockAxelarGasService.sol";
import {RootERC20Bridge, IRootERC20BridgeEvents, IERC20Metadata} from "../../../../src/root/RootERC20Bridge.sol";
import {RootAxelarBridgeAdaptor, IRootAxelarBridgeAdaptorEvents} from "../../../../src/root/RootAxelarBridgeAdaptor.sol";
import {Utils} from "../../../utils.t.sol";
import {WETH} from "../../../../src/test/root/WETH.sol";

contract RootERC20BridgeWithdrawIntegrationTest is Test, IRootERC20BridgeEvents, IRootAxelarBridgeAdaptorEvents, Utils {
    address constant CHILD_BRIDGE = address(3);
    address constant CHILD_BRIDGE_ADAPTOR = address(4);
    string constant CHILD_CHAIN_NAME = "CHILD";
    address constant IMX_TOKEN_ADDRESS = address(0xccc);
    address constant NATIVE_ETH = address(0xeee);
    address constant WRAPPED_ETH = address(0xddd);

    uint256 constant withdrawAmount = 0.5 ether;

    ERC20PresetMinterPauser public token;
    ERC20PresetMinterPauser public imxToken;
    RootERC20Bridge public rootBridge;
    RootAxelarBridgeAdaptor public axelarAdaptor;
    MockAxelarGateway public mockAxelarGateway;
    MockAxelarGasService public axelarGasService;

    function setUp() public {
        deployCodeTo("WETH.sol", abi.encode("Wrapped ETH", "WETH"), WRAPPED_ETH);

        (imxToken, token, rootBridge, axelarAdaptor, mockAxelarGateway, axelarGasService) =
            rootIntegrationSetup(CHILD_BRIDGE, CHILD_BRIDGE_ADAPTOR, CHILD_CHAIN_NAME, IMX_TOKEN_ADDRESS, WRAPPED_ETH);

        // Need to first map the token.
        rootBridge.mapToken{value:1}(token);
        // And give the bridge some tokens
        token.transfer(address(rootBridge), 100 ether);
    }

    function test_withdraw_TransfersTokens() public {
        bytes memory data = abi.encode(WITHDRAW_SIG, address(token), address(this), address(this), withdrawAmount);

        bytes32 commandId = bytes32("testCommandId");
        string memory sourceAddress = rootBridge.childBridgeAdaptor();

        uint256 thisPreBal = token.balanceOf(address(this));
        uint256 bridgePreBal = token.balanceOf(address(rootBridge));

        axelarAdaptor.execute(commandId, CHILD_CHAIN_NAME, sourceAddress, data);

        uint256 thisPostBal = token.balanceOf(address(this));
        uint256 bridgePostBal = token.balanceOf(address(rootBridge));

        assertEq(thisPostBal, thisPreBal + withdrawAmount, "Incorrect user balance after withdraw");
        assertEq(bridgePostBal, bridgePreBal - withdrawAmount, "Incorrect bridge balance after withdraw");
    }

    function test_withdraw_TransfersTokens_DifferentReceiver() public {
        address receiver = address(987654321);
        bytes memory data = abi.encode(WITHDRAW_SIG, address(token), address(this), receiver, withdrawAmount);

        bytes32 commandId = bytes32("testCommandId");
        string memory sourceAddress = rootBridge.childBridgeAdaptor();

        uint256 receiverPreBal = token.balanceOf(receiver);
        uint256 bridgePreBal = token.balanceOf(address(rootBridge));

        axelarAdaptor.execute(commandId, CHILD_CHAIN_NAME, sourceAddress, data);

        uint256 receiverPostBal = token.balanceOf(receiver);
        uint256 bridgePostBal = token.balanceOf(address(rootBridge));

        assertEq(receiverPostBal, receiverPreBal + withdrawAmount, "Incorrect user balance after withdraw");
        assertEq(bridgePostBal, bridgePreBal - withdrawAmount, "Incorrect bridge balance after withdraw");
    }

    function test_withdraw_EmitsRootChainERC20WithdrawEvent() public {
        bytes memory data = abi.encode(WITHDRAW_SIG, address(token), address(this), address(this), withdrawAmount);

        bytes32 commandId = bytes32("testCommandId");
        string memory sourceAddress = rootBridge.childBridgeAdaptor();

        vm.expectEmit();
        emit RootChainERC20Withdraw(address(token), rootBridge.rootTokenToChildToken(address(token)), address(this), address(this), withdrawAmount);
        axelarAdaptor.execute(commandId, CHILD_CHAIN_NAME, sourceAddress, data);
    }
}
