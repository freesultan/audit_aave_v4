// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;
//@>i this Premium contract uses safeCase from OZ, why dn't others use this? they have to manage it themselves
import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';

/// @title Premium library
/// @author Aave Labs
/// @notice Implements the premium calculations.
library Premium {
  using SafeCast for *;

  /// @notice Calculates the premium debt with full precision.
  /// @param premiumShares The number of premium shares.
  /// @param premiumOffsetRay The premium offset, expressed in asset units and scaled by RAY.
  /// @param drawnIndex The current drawn index.
  /// @return The premium debt, expressed in asset units and scaled by RAY.
  function calculatePremiumRay(
    uint256 premiumShares,
    int256 premiumOffsetRay,
    uint256 drawnIndex
  ) internal pure returns (uint256) {
    //@>i primiumShares x drawnIndex - premiumOffsetRay
    return ((premiumShares * drawnIndex).toInt256() - premiumOffsetRay).toUint256();
  }
}
