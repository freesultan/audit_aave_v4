// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {SignatureChecker} from 'src/dependencies/openzeppelin/SignatureChecker.sol';
import {SafeERC20, IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {IERC20Permit} from 'src/dependencies/openzeppelin/IERC20Permit.sol';
//@>q what are this solady contract security considerations?
import {EIP712} from 'src/dependencies/solady/EIP712.sol';

import {MathUtils} from 'src/libraries/math/MathUtils.sol';

import {NoncesKeyed} from 'src/utils/NoncesKeyed.sol';
//@>q check multicall. it can the source of a bug as in multicalls if the multical reverts the signature of some calls may remain valid and suseptible to replay attack
import {Multicall} from 'src/utils/Multicall.sol';
//@>audit: Everyone can call multical function through this contract.

//@>i EIP712Types are structs for function parameters like withdraw, borrow, ...
//@>i EIP712Hash hash functioni for function parameters which get params as eip712types and return hash of hashconstant + parameters
import {EIP712Hash, EIP712Types} from 'src/position-manager/libraries/EIP712Hash.sol';

import {GatewayBase} from 'src/position-manager/GatewayBase.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {ISignatureGateway} from 'src/position-manager/interfaces/ISignatureGateway.sol';

/// @title SignatureGateway
/// @author Aave Labs
/// @notice Gateway to consume EIP-712 typed intents for spoke actions on behalf of a user.
/// @dev Contract must be an active & approved user position manager to execute spoke actions on user's behalf.
//@>q what does this line mean?
/// @dev Uses keyed-nonces where each key's namespace nonce is consumed sequentially. Intents bundled through
/// multicall can be executed independently in order of signed nonce & deadline; does not guarantee batch atomicity.

contract SignatureGateway is ISignatureGateway, GatewayBase, NoncesKeyed, Multicall, EIP712 {
  using SafeERC20 for IERC20;
  using EIP712Hash for *;




  /// @dev Constructor.
  /// @param initialOwner_ The address of the initial owner.
  constructor(address initialOwner_) GatewayBase(initialOwner_) {}

  /// @inheritdoc ISignatureGateway
  function supplyWithSig(
    EIP712Types.Supply calldata params,
    bytes calldata signature
  ) external onlyRegisteredSpoke(params.spoke) returns (uint256, uint256) {
    require(block.timestamp <= params.deadline, InvalidSignature());
    address spoke = params.spoke;
    uint256 reserveId = params.reserveId;
    address user = params.onBehalfOf;
    //@>i we can use params.hash() as EIP712Hash library can be used for * 
    //@>i _hashTypedData is a function from soldy eip712 contract which gets a hash and returns a digest
    bytes32 digest = _hashTypedData(params.hash());
    require(SignatureChecker.isValidSignatureNow(user, digest, signature), InvalidSignature());
    _useCheckedNonce(user, params.nonce);

     //@>i the following function lines are the same as NativeTokenGateway
    IERC20 underlying = IERC20(_getReserveUnderlying(spoke, reserveId));
    underlying.safeTransferFrom(user, address(this), params.amount);
    underlying.forceApprove(spoke, params.amount);

    return ISpoke(spoke).supply(reserveId, params.amount, user);
  }

  /// @inheritdoc ISignatureGateway
  function withdrawWithSig(
    EIP712Types.Withdraw calldata params,
    bytes calldata signature
  ) external onlyRegisteredSpoke(params.spoke) returns (uint256, uint256) {
    require(block.timestamp <= params.deadline, InvalidSignature());
    address spoke = params.spoke;
    uint256 reserveId = params.reserveId;
    address user = params.onBehalfOf;
    bytes32 digest = _hashTypedData(params.hash());
    require(SignatureChecker.isValidSignatureNow(user, digest, signature), InvalidSignature());
    _useCheckedNonce(user, params.nonce);

    IERC20 underlying = IERC20(_getReserveUnderlying(spoke, reserveId));
    (uint256 withdrawnShares, uint256 withdrawnAmount) = ISpoke(spoke).withdraw(
      reserveId,
      params.amount,
      user
    );
    underlying.safeTransfer(user, withdrawnAmount);

    return (withdrawnShares, withdrawnAmount);
  }

  /// @inheritdoc ISignatureGateway
  function borrowWithSig(
    EIP712Types.Borrow calldata params,
    bytes calldata signature
  ) external onlyRegisteredSpoke(params.spoke) returns (uint256, uint256) {
    require(block.timestamp <= params.deadline, InvalidSignature());
    address spoke = params.spoke;
    uint256 reserveId = params.reserveId;
    address user = params.onBehalfOf;
    bytes32 digest = _hashTypedData(params.hash());
    //@>i isValidSignatureNow from OZ signatureChecker. the outcome of this function can thus
   // change through time. It could return true at block N and false at block N+1 
    require(SignatureChecker.isValidSignatureNow(user, digest, signature), InvalidSignature());
    //@>i params.nonce in eip712Types is 256bit so it is a keyNonce
    //@>i use nonce and increments it by 1
    _useCheckedNonce(user, params.nonce);

    IERC20 underlying = IERC20(_getReserveUnderlying(spoke, reserveId));
    (uint256 borrowedShares, uint256 borrowedAmount) = ISpoke(spoke).borrow(
      reserveId,
      params.amount,
      user
    );
    underlying.safeTransfer(user, borrowedAmount);

    return (borrowedShares, borrowedAmount);
  }

  /// @inheritdoc ISignatureGateway
  function repayWithSig(
    EIP712Types.Repay calldata params,
    bytes calldata signature
  ) external onlyRegisteredSpoke(params.spoke) returns (uint256, uint256) {
    require(block.timestamp <= params.deadline, InvalidSignature());
    address spoke = params.spoke;
    uint256 reserveId = params.reserveId;
    address user = params.onBehalfOf;
    //@>i 
    //@>i _hashTypedData is in eip712 from Solady
    bytes32 digest = _hashTypedData(params.hash());
    require(SignatureChecker.isValidSignatureNow(user, digest, signature), InvalidSignature());
    _useCheckedNonce(user, params.nonce);

    IERC20 underlying = IERC20(_getReserveUnderlying(spoke, reserveId));

    uint256 repayAmount = MathUtils.min(
      params.amount,
      ISpoke(spoke).getUserTotalDebt(reserveId, user)
    );

    underlying.safeTransferFrom(user, address(this), repayAmount);
    //@>i here we approve spoke for repayAmount
    underlying.forceApprove(spoke, repayAmount);
    //@>i repayAmount can not be more that userTotalDebt
    return ISpoke(spoke).repay(reserveId, repayAmount, user);
  }


  /// @inheritdoc ISignatureGateway
  function setUsingAsCollateralWithSig(
    EIP712Types.SetUsingAsCollateral calldata params,
    bytes calldata signature
  ) external onlyRegisteredSpoke(params.spoke) {
    require(block.timestamp <= params.deadline, InvalidSignature());
    address user = params.onBehalfOf;
    bytes32 digest = _hashTypedData(params.hash());
    require(SignatureChecker.isValidSignatureNow(user, digest, signature), InvalidSignature());
    _useCheckedNonce(user, params.nonce);

    ISpoke(params.spoke).setUsingAsCollateral(params.reserveId, params.useAsCollateral, user);
  }

  /// @inheritdoc ISignatureGateway
  function updateUserRiskPremiumWithSig(
    EIP712Types.UpdateUserRiskPremium calldata params,
    bytes calldata signature
  ) external onlyRegisteredSpoke(params.spoke) {
    require(block.timestamp <= params.deadline, InvalidSignature());
    bytes32 digest = _hashTypedData(params.hash());
    require(
      SignatureChecker.isValidSignatureNow(params.user, digest, signature),
      InvalidSignature()
    );
    _useCheckedNonce(params.user, params.nonce);

    ISpoke(params.spoke).updateUserRiskPremium(params.user);
  }


  /// @inheritdoc ISignatureGateway
  function updateUserDynamicConfigWithSig(
    EIP712Types.UpdateUserDynamicConfig calldata params,
    bytes calldata signature
  ) external onlyRegisteredSpoke(params.spoke) {
    //@>i check deadline, singature validation, consume nonce from input calldata
    require(block.timestamp <= params.deadline, InvalidSignature());

    bytes32 digest = _hashTypedData(params.hash());
    require(
      SignatureChecker.isValidSignatureNow(params.user, digest, signature),
      InvalidSignature()
    );
    _useCheckedNonce(params.user, params.nonce);

    ISpoke(params.spoke).updateUserDynamicConfig(params.user);
  }

  /// @inheritdoc ISignatureGateway
  function setSelfAsUserPositionManagerWithSig(
    address spoke,
    EIP712Types.SetUserPositionManager calldata params,
    bytes calldata signature
  ) external onlyRegisteredSpoke(spoke) {
    try
      //@>q this limits setUserPositionManagerWithSig to this position manager. can we call setUserPositionManagerWithSig directly?
      ISpoke(spoke).setUserPositionManagerWithSig(
        address(this),
        params.user,
        params.approve,
        params.nonce,
        params.deadline,
        signature
      )
    {} catch {}
  }

  /// @inheritdoc ISignatureGateway
  function permitReserve(
    address spoke,
    uint256 reserveId,
    address onBehalfOf,
    uint256 value,
    uint256 deadline,
    uint8 permitV,
    bytes32 permitR,
    bytes32 permitS
  ) external onlyRegisteredSpoke(spoke) {
    //@>i gassless signature-based approve for spender(this gateway contract)
    address underlying = _getReserveUnderlying(spoke, reserveId);
    try
      IERC20Permit(underlying).permit({
        //@>q in permit doc they recommend to use msg.sener as the owner. can using onBehalfOf introduce vulns?
        owner: onBehalfOf,
        spender: address(this),
        value: value,
        deadline: deadline,
        v: permitV,
        r: permitR,
        s: permitS
      })
    {} catch {}
    //@>q permitREserve has security considerations. where does this function is used?
  }
//@>i Users can get typehashes constants and sign their intents with them
  /// @inheritdoc ISignatureGateway
  function DOMAIN_SEPARATOR() external view returns (bytes32) {
    return _domainSeparator();
  }

  /// @inheritdoc ISignatureGateway
  function SUPPLY_TYPEHASH() external pure returns (bytes32) {
    return EIP712Hash.SUPPLY_TYPEHASH;
  }

  /// @inheritdoc ISignatureGateway
  function WITHDRAW_TYPEHASH() external pure returns (bytes32) {
    return EIP712Hash.WITHDRAW_TYPEHASH;
  }

  /// @inheritdoc ISignatureGateway
  function BORROW_TYPEHASH() external pure returns (bytes32) {
    return EIP712Hash.BORROW_TYPEHASH;
  }

  /// @inheritdoc ISignatureGateway
  function REPAY_TYPEHASH() external pure returns (bytes32) {
    return EIP712Hash.REPAY_TYPEHASH;
  }

  /// @inheritdoc ISignatureGateway
  function SET_USING_AS_COLLATERAL_TYPEHASH() external pure returns (bytes32) {
    return EIP712Hash.SET_USING_AS_COLLATERAL_TYPEHASH;
  }

  /// @inheritdoc ISignatureGateway
  function UPDATE_USER_RISK_PREMIUM_TYPEHASH() external pure returns (bytes32) {
    return EIP712Hash.UPDATE_USER_RISK_PREMIUM_TYPEHASH;
  }

  /// @inheritdoc ISignatureGateway
  function UPDATE_USER_DYNAMIC_CONFIG_TYPEHASH() external pure returns (bytes32) {
    return EIP712Hash.UPDATE_USER_DYNAMIC_CONFIG_TYPEHASH;
  }

  function _domainNameAndVersion() internal pure override returns (string memory, string memory) {
    return ('SignatureGateway', '1');
  }
}
