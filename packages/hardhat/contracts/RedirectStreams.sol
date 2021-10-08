//SPDX-License-Identifier: MIT
pragma solidity ^0.7.1;

import "hardhat/console.sol";

import {
    ISuperfluid,
    ISuperApp,
    ISuperAgreement,
    ISuperToken,
    SuperAppDefinitions
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

import {
    IConstantFlowAgreementV1
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";

import {
    ISETHCustom
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/tokens/ISETH.sol";

import {
    SuperAppBase
} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperAppBase.sol";


contract RedirectStreams is SuperAppBase {
    address public primaryReceiver;
    ISuperfluid private _host;
    IConstantFlowAgreementV1 private _cfa;
    ISETHCustom private _ethUpgrader;
    ISuperToken private _ethx;


    constructor(ISuperfluid host, IConstantFlowAgreementV1 cfa, ISuperToken ethx) payable {
        _host = host;
        _cfa = cfa;
        _ethx = ethx;
        _ethUpgrader = ISETHCustom(address(ethx));

        uint256 configWord =
            SuperAppDefinitions.APP_LEVEL_FINAL |
            SuperAppDefinitions.BEFORE_AGREEMENT_CREATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_UPDATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_TERMINATED_NOOP;

        _host.registerApp(configWord);
        _ethUpgrader.upgradeByETH{value: msg.value}();
    }

    function _changePrimaryReceiver(address newPrimaryReceiver) internal {
        int96 oldReceiverFlowRate = _getOutflowRate(primaryReceiver);
        int96 newReceiverFlowRate = _getOutflowRate(newPrimaryReceiver);

        _updateOutflow(primaryReceiver, int96(0));
        _updateOutflow(newPrimaryReceiver, oldReceiverFlowRate + newReceiverFlowRate);
        primaryReceiver = newPrimaryReceiver;
    }

    function _updatePrimaryOutflow() internal {
        int96 flowRateChange = _cfa.getNetFlow(_ethx, address(this));
        int96 oldOutflowRate = _getOutflowRate(primaryReceiver);
        int96 newOutFlowRate = oldOutflowRate + flowRateChange;
        console.log(uint256(flowRateChange), uint256(oldOutflowRate), uint256(newOutFlowRate));
        if (newOutFlowRate >= 0) {
            _updateOutflow(primaryReceiver, newOutFlowRate);
        }

    }

    function _updatePrimaryOutflowWithContext(bytes calldata ctx) private returns (bytes memory newCtx) {
        // This function is called after the stream incoming to the salary anchor NFT has changed.
        newCtx = ctx;

        // netFlowRate should always be zero between transactions so right after the change in inflows it should be equal to this change. 
        int96 flowRateChange = _cfa.getNetFlow(_ethx, address(this));
        int96 oldOutflowRate = _getOutflowRate(primaryReceiver);

        // If the incoming salary increased then the additional income goes to the primary receiver.
        // If the incoming salary decreased then then this amount is deduced from the flow to the primary receiver.
        int96 newOutFlowRate = oldOutflowRate + flowRateChange;

        if (newOutFlowRate >= 0) {
            newCtx = _updateOutflowWithContext(primaryReceiver, newOutFlowRate, ctx);
        }
        // Case when incoming salary can no longer cover all outflows (expenses).
        // What should we do here? Let the Superfluid protocol handle this case?
        // There are some Licensed Agents that close insolvent streams as described here: https://docs.superfluid.finance/superfluid/docs/constant-flow-agreement
        // It's an edge case for purposes of this hackathon so let's assume this will be handled by the protocol.
    }

    // helpers for updating outflows
    function _updateOutflow(address receiver, int96 newFlowRate) internal {
        int96 oldFlowRate = _getOutflowRate(receiver);
         // In case of an attmept to delete a non-existent outflow, we should just do nothing.
        if (oldFlowRate == int96(0) && newFlowRate == int96(0)) return;
        // update the outflow
        bytes memory txData = _getUpdateOutflowTxData(receiver, oldFlowRate, newFlowRate);
        _host.callAgreement(_cfa, txData, "0x");
    }

    function _updateOutflowWithContext(address receiver, int96 newFlowRate, bytes calldata ctx) internal returns (bytes memory newCtx)  {
        newCtx = ctx;
        int96 oldFlowRate = _getOutflowRate(receiver);
        // It's an attmept to delete a non-existent outflow. We should just do nothing.
        if (oldFlowRate == int96(0) && newFlowRate == int96(0)) return newCtx;
        // update the outflow
        bytes memory txData = _getUpdateOutflowTxData(receiver, oldFlowRate, newFlowRate);
        (newCtx, ) = _host.callAgreementWithContext(_cfa, txData, "0x", newCtx);
    }

    function _getUpdateOutflowTxData(address receiver, int96 oldFlowRate, int96 newFlowRate) private view returns (bytes memory txData) {
        // Should we delete, update or create the stream?
        if (newFlowRate == int96(0)) {
            // newFlowRate is 0 but the stream exists because oldFlowRate is non-zero. We should delete this stream.
            txData = abi.encodeWithSelector(_cfa.deleteFlow.selector, _ethx, address(this), receiver, new bytes(0));
        } else if (oldFlowRate != int96(0)) {
            // both old and new flow rates have non-zero values so we should just update this outflow.  
            txData = abi.encodeWithSelector(_cfa.updateFlow.selector, _ethx, receiver, newFlowRate, new bytes(0));
        } else {
            // oldFlowRate is zero so the stream doesn't exist but newFlowRate one is non-zero so we should create the stream.
            txData = abi.encodeWithSelector(_cfa.createFlow.selector, _ethx, receiver, newFlowRate, new bytes(0));
        }
    }

    function _getOutflowRate(address receiver) private view returns (int96 flowRate) {
        (,flowRate,,) = _cfa.getFlow(_ethx, address(this), receiver);
    }

    // callbacks
    function afterAgreementCreated(
        ISuperToken _superToken, address _agreementClass, bytes32, bytes calldata, bytes calldata, bytes calldata _ctx
    )
    external override 
    onlyExpected(_superToken, _agreementClass) onlyHost
    returns (bytes memory newCtx) {
        return _updatePrimaryOutflowWithContext(_ctx);
    }

    function afterAgreementUpdated(
        ISuperToken _superToken, address _agreementClass, bytes32, bytes calldata, bytes calldata, bytes calldata _ctx
    ) 
    external override 
    onlyExpected(_superToken, _agreementClass) onlyHost 
    returns (bytes memory newCtx) {
        console.log("ddd");
        return _updatePrimaryOutflowWithContext(_ctx);
    }

    function afterAgreementTerminated(
        ISuperToken _superToken, address _agreementClass, bytes32, bytes calldata, bytes calldata, bytes calldata _ctx
    ) 
    external override 
    onlyHost 
    returns (bytes memory newCtx) {
        if (!_isSameToken(_superToken) || !_isCFAv1(_agreementClass)) return _ctx;
        return _updatePrimaryOutflowWithContext(_ctx);
    }

    // modifiers
    modifier onlyHost() {
        require(msg.sender == address(_host), "RedirectStreams: support only one host");
        _;
    }

    modifier onlyExpected(ISuperToken superToken, address agreementClass) {
        require(_isSameToken(superToken), "RedirectStreams: not accepted token");
        require(_isCFAv1(agreementClass), "RedirectStreams: only CFAv1 supported");
        _;
    }

    // helpers for checks
    function _isSameToken(ISuperToken superToken) private view returns (bool) {
        return address(superToken) == address(_ethx);
    }

    function _isCFAv1(address agreementClass) private view returns (bool) {
        return ISuperAgreement(agreementClass).agreementType() == keccak256("org.superfluid-finance.agreements.ConstantFlowAgreement.v1");
    }
}
