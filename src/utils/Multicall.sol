// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

//@>i user can use multicall to batch multiple calls into a single call from the contract that inherits this contract
/* Users can batch multiple lending operations
bytes[] memory ops = new bytes[](3);
ops[0] = abi.encodeWithSignature("supply(address,uint256)", asset, amount);
ops[1] = abi.encodeWithSignature("borrow(address,uint256)", asset, amount);
ops[2] = abi.encodeWithSignature("withdraw(address,uint256)", asset, amount);

spoke.multicall(ops);
*/

import {IMulticall} from 'src/interfaces/IMulticall.sol';
//@>i this multicall is inspired by OZ Multicall contract. is it implemented correctly and dose the OZ multicall contract have security considerations?
/// @title Multicall
/// @author Aave Labs
/// @notice This contract allows for batching multiple calls into a single call.
/// @dev Inspired by the OpenZeppelin Multicall contract.
abstract contract Multicall is IMulticall {
  //@>i Call multiple functions in the current contract and return the data from each if they all succeed
  //@>audit who uses this multical in the protocol? the spoke and signatureGateway contracts use it. 
  /// @inheritdoc IMulticall
  function multicall(bytes[] calldata data) external returns (bytes[] memory) {
     bytes[] memory results = new bytes[](data.length);
    for (uint256 i; i < data.length; ++i) {
      //@>i the input calls are executed in the context of the current contract using delegatecall
      //@>i this means uses signatureGateway and spoke contract storage and msg.sender
      (bool ok, bytes memory res) = address(this).delegatecall(data[i]);

      assembly ('memory-safe') {
        if iszero(ok) {
          //@>i If any call fails, the entire transaction reverts and bubbles up the revert reason
          revert(add(res, 32), mload(res)) // bubble up first revert
        }
      }
      /*@>i 
      // These two are equally secure:
      // Option A: Individual calls
      signatureGateway.function1();
      signatureGateway.function2();

      // Option B: Multicall
      signatureGateway.multicall([call1, call2]);
      // Same access controls apply to both
      */

      results[i] = res;
    }
    return results;
  }
}
