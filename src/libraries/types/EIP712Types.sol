// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

/// @title EIP712Types library
/// @author Aave Labs
/// @notice Defines type structs used in EIP712-typed signatures.
library EIP712Types {
  //@>i all eip712 types have nonce and deadline
  struct SetUserPositionManager {
    address positionManager;
    address user;
    bool approve;
    uint256 nonce;
    uint256 deadline;
  }
//@>i in permits, owner approve spender to spend value
  struct Permit {
    address owner;
    address spender;
    uint256 value;
    uint256 nonce;
    uint256 deadline;
  }

  struct Supply {
    address spoke;
    uint256 reserveId;
    uint256 amount;
    address onBehalfOf;
    uint256 nonce;
    uint256 deadline;
  }

  struct Withdraw {
    address spoke;
    uint256 reserveId;
    uint256 amount;
    address onBehalfOf;
    uint256 nonce;
    uint256 deadline;
  }

  struct Borrow {
    address spoke;
    uint256 reserveId;
    uint256 amount;
    address onBehalfOf;
    uint256 nonce;
    uint256 deadline;
  }

  struct Repay {
    address spoke;
    uint256 reserveId;
    uint256 amount;
    address onBehalfOf;
    uint256 nonce;
    uint256 deadline;
  }

  struct SetUsingAsCollateral {
    address spoke;
    uint256 reserveId;
    bool useAsCollateral;
    address onBehalfOf;
    uint256 nonce;
    uint256 deadline;
  }
//@>i updateUserRiskPremium and updateUerDynamicConfig 
  struct UpdateUserRiskPremium {
    address spoke;
    address user;
    uint256 nonce;
    uint256 deadline;
  }
//@>i does this update user positions dynamic configs to the latest dynamic configs for all his reservs?
//@>i yes for all collateral reserves of the user
  struct UpdateUserDynamicConfig {
    address spoke;
    address user;
    uint256 nonce;
    uint256 deadline;
  }
}
