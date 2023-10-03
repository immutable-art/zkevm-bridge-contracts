// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.17;

interface IRootAxelarBridgeAdaptorErrors {
    error ZeroAddresses();
    error InvalidChildChain();
    error NoGas();
    error CallerNotBridge();
    error InvalidArrayLengths();
}

interface IRootAxelarBridgeAdaptorEvents {
    event MapTokenAxelarMessage(string indexed childChain, string indexed childBridgeAdaptor, bytes indexed payload);
}
