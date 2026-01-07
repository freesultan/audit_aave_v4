// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.10;

import 'tests/Base.t.sol';
import {console} from "forge-std/console.sol"; // Import console logging


contract NoncesKeyedTest is Base {
  using SafeCast for *;
  MockNoncesKeyed public mock;

  function setUp() public override {
    mock = new MockNoncesKeyed();
  }
  //@>i add bytes32 as input to make it fuzzable
  function test_useNonce_monotonic() public {
    vm.setArbitraryStorage(address(mock));

    //address owner = vm.randomAddress();
   // uint192 key = _randomNonceKey(); //@>i returns a random 192 bit number
   address owner = makeAddr("0xowner");
    uint192 key = uint192(0x1);
    console.log("=== test_useNonce_monotonic ===");
    console.log("Owner address:", owner);
    //console.logBytes32(bytes32(uint256(key))); // Show the key as bytes32
    console.log("Key (uint192):", uint256(key));
    uint256 keyNonce = mock.nonces(owner, key);
    console.log("Current nonce for (owner, key):", keyNonce);

    vm.prank(owner);
    uint256 consumedKeyNonce = mock.useNonce(key);
    console.log("Consumed nonce:", consumedKeyNonce);
    console.log("New nonce for (owner, key):", mock.nonces(owner, key));

    assertEq(consumedKeyNonce, keyNonce);
    _assertNonceIncrement(mock, owner, keyNonce);
  }

  function test_useCheckedNonce_monotonic(bytes32) public {
    vm.setArbitraryStorage(address(mock));

    address owner = vm.randomAddress();
    uint192 key = _randomNonceKey();

    uint256 keyNonce = mock.nonces(owner, key);

    mock.useCheckedNonce(owner, keyNonce);

    _assertNonceIncrement(mock, owner, keyNonce);
  }

  function test_useCheckedNonce_revertsWith_InvalidAccountNonce(bytes32) public {
    vm.setArbitraryStorage(address(mock));

    address owner = vm.randomAddress();
    uint192 key = _randomNonceKey();

    uint256 currentNonce = _burnRandomNoncesAtKey(mock, owner, key);
    uint256 invalidNonce = _getRandomInvalidNonceAtKey(mock, owner, key);

    vm.expectRevert(
      abi.encodeWithSelector(INoncesKeyed.InvalidAccountNonce.selector, owner, currentNonce)
    );
    mock.useCheckedNonce(owner, invalidNonce);
  }
}
