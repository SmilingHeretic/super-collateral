//SPDX-License-Identifier: MIT
pragma solidity ^0.7.1;

import "hardhat/console.sol";

import {
    ISuperfluid,
    ISuperToken,
    ISuperApp,
    ISuperAgreement,
    SuperAppDefinitions
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

import {
    IConstantFlowAgreementV1
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";

import {
    SuperAppBase
} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperAppBase.sol";


contract RedirectAll is SuperAppBase {
    ISuperfluid private _host;
    IConstantFlowAgreementV1 private _cfa;
    ISuperToken private _acceptedToken;
    address private _receiver;
    

    constructor(ISuperfluid host, IConstantFlowAgreementV1 cfa, ISuperToken acceptedToken, address receiver) {
        _host = host;
        _cfa = cfa;
        _acceptedToken = acceptedToken;
        _receiver = receiver;


        uint256 configWord =
            SuperAppDefinitions.APP_LEVEL_FINAL |
            SuperAppDefinitions.BEFORE_AGREEMENT_CREATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_UPDATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_TERMINATED_NOOP;

        _host.registerApp(configWord);
    }

    function currentReceiver() external view returns (uint256 startTime, address receiver, int96 flowRate) {
        (startTime, flowRate,,) = _cfa.getFlow(_acceptedToken, address(this), _receiver);
        receiver = _receiver;
    }


    function _updateOutflow(bytes calldata ctx) private returns (bytes memory newCtx) {
        // This function is called after the stream incoming to the salary anchor NFT has changed.
        newCtx = ctx;
        // inFlowRate is the new flow rate incoming to the NFT.
        // outFlowRate is the old flow rate of the stream NFT -> its owner.
        // After the update we want outFlowRate to equal inFlowRate.
        (int96 inFlowRate, int96 outFlowRate) = _getFlowRates();

        // Should we delete, update or create the stream from NFT to its owner?
        bytes memory data;
        if (inFlowRate == int96(0)) {
            // Money stream incoming to the NFT just stopped so we're deleting to stream to the owner too.
            data = abi.encodeWithSelector(_cfa.deleteFlow.selector, _acceptedToken, address(this), _receiver, new bytes(0));
        } else if (outFlowRate != int96(0)) {
            // Both streams employer -> NFT and NFT -> owner are non zero so we're just updating the latter with new value.
            data = abi.encodeWithSelector(_cfa.updateFlow.selector, _acceptedToken, _receiver, inFlowRate, new bytes(0));
        } else {
            // Inflow to NFT just started so we need to create the stream NFT -> owner.
            data = abi.encodeWithSelector(_cfa.createFlow.selector, _acceptedToken, _receiver, inFlowRate, new bytes(0));
        }
        (newCtx, ) = _host.callAgreementWithContext(_cfa, data, "0x", newCtx);
    }

    function _changeReceiver( address newReceiver ) internal {
        // This function is called right before transfer of the NFT to the new owner so _receiver is still the old owner.
        bytes memory data;

        // Get flow rates: to NFT and NFT -> old owner. They should be equal.
        (int96 inFlowRate, int96 outFlowRate) = _getFlowRates();

        // Stop the stream NFT -> old owner if it exists.
        if (outFlowRate > 0) {
            data = abi.encodeWithSelector(_cfa.deleteFlow.selector, _acceptedToken, address(this), _receiver, new bytes(0));
            _host.callAgreement(_cfa, data, "0x");
        }

        // Start stream NFT -> new owner if there's inflow to the NFT.
        if (inFlowRate > 0) {
            data = abi.encodeWithSelector(_cfa.createFlow.selector, _acceptedToken, newReceiver, inFlowRate, new bytes(0));
            _host.callAgreement(_cfa, data, "0x");
        }

        // Update the _receiver.
        _receiver = newReceiver;
    }

    // callbacks
    function afterAgreementCreated(
        ISuperToken _superToken, address _agreementClass, bytes32, bytes calldata, bytes calldata, bytes calldata _ctx
    )
    external override 
    onlyExpected(_superToken, _agreementClass) onlyHost
    returns (bytes memory newCtx) {
        return _updateOutflow(_ctx);
    }

    function afterAgreementUpdated(
        ISuperToken _superToken, address _agreementClass, bytes32, bytes calldata, bytes calldata, bytes calldata _ctx
    ) 
    external override 
    onlyExpected(_superToken, _agreementClass) onlyHost 
    returns (bytes memory newCtx) {
        return _updateOutflow(_ctx);
    }

    function afterAgreementTerminated(
        ISuperToken _superToken, address _agreementClass, bytes32, bytes calldata, bytes calldata, bytes calldata _ctx
    ) 
    external override 
    onlyHost 
    returns (bytes memory newCtx) {
        if (!_isSameToken(_superToken) || !_isCFAv1(_agreementClass)) return _ctx;
        return _updateOutflow(_ctx);
    }

    // modifiers
    modifier onlyHost() {
        require(msg.sender == address(_host), "RedirectAll: support only one host");
        _;
    }

    modifier onlyExpected(ISuperToken superToken, address agreementClass) {
        require(_isSameToken(superToken), "RedirectAll: not accepted token");
        require(_isCFAv1(agreementClass), "RedirectAll: only CFAv1 supported");
        _;
    }

    // helpers
    function _isSameToken(ISuperToken superToken) private view returns (bool) {
        return address(superToken) == address(_acceptedToken);
    }

    function _isCFAv1(address agreementClass) private view returns (bool) {
        return ISuperAgreement(agreementClass).agreementType() == keccak256("org.superfluid-finance.agreements.ConstantFlowAgreement.v1");
    }

    function _getFlowRates() private view returns (int96 inFlowRate, int96 outFlowRate) {
        int96 netFlowRate = _cfa.getNetFlow(_acceptedToken, address(this));
        (,outFlowRate,,) = _cfa.getFlow(_acceptedToken, address(this), _receiver);
        inFlowRate = netFlowRate + outFlowRate;
    }
}
