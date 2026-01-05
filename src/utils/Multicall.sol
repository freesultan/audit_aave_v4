// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

import {IMulticall} from 'src/interfaces/IMulticall.sol';
//@>q this multicall is inspired by OZ Multicall contract. is it implemented correctly and dose the OZ multicall contract have security considerations?
/// @title Multicall
/// @author Aave Labs
/// @notice This contract allows for batching multiple calls into a single call.
/// @dev Inspired by the OpenZeppelin Multicall contract.
abstract contract Multicall is IMulticall {
  //@>i Call multiple functions in the current contract and return the data from each if they all succeed
  //@>q who uses this multical in the protocol? if no one, external user can call this? the spoke
  /// @inheritdoc IMulticall
  function multicall(bytes[] calldata data) external returns (bytes[] memory) {
    //@>q how does this function work deeply? how do users call this? can they?
    bytes[] memory results = new bytes[](data.length);
    for (uint256 i; i < data.length; ++i) {
      (bool ok, bytes memory res) = address(this).delegatecall(data[i]);

      assembly ('memory-safe') {
        if iszero(ok) {
          revert(add(res, 32), mload(res)) // bubble up first revert
        }
      }

      results[i] = res;
    }
    return results;
  }
}
