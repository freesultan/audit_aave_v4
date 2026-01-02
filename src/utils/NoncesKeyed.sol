// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

import {INoncesKeyed} from 'src/interfaces/INoncesKeyed.sol';
//@>q this is forked from OZ NoncesKeyed. check if the differences create new vulnerabilites?
/// @notice Provides tracking nonces for addresses. Supports key-ed nonces, where nonces will only increment for each key.
/// @author Modified from OpenZeppelin https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.2.0/contracts/utils/NoncesKeyed.sol
//@>q this implementation try to impelement eip4337. check if they are doing it right?
/// @dev Follows the https://eips.ethereum.org/EIPS/eip-4337#semi-abstracted-nonce-support[ERC-4337's semi-abstracted nonce system].

contract NoncesKeyed is INoncesKeyed {
  //@>i the noncekeyed contract maintain a list of nonces for each user address
  mapping(address owner => mapping(uint192 key => uint64 nonce)) private _nonces;

  //@>i each keyNonce is 32 byte(256b) : [key(24B(192b))+nonce(8B(64b))]
  /// @inheritdoc INoncesKeyed
  function useNonce(uint192 key) external returns (uint256) {
    return _useNonce(msg.sender, key);
  }
  
  //@>i returns all nonces of a [user,key]
  /// @inheritdoc INoncesKeyed
  function nonces(address owner, uint192 key) external view returns (uint256) {
    return _pack(key, _nonces[owner][key]);
  }

  //@>i each [userAddress, key] can have many nonces which I guess starts from 0 and increments

  /// @notice Consumes the next unused nonce for an address and key.
  /// @dev Returns the current packed `keyNonce`. Consumed nonce is increased, so calling this function twice
  /// with the same arguments will return different (sequential) results.
  //@>i returns The nonce value BEFORE incrementing (the current/used nonce)
  function _useNonce(address owner, uint192 key) internal returns (uint256) {
    // For each account, the nonce has an initial value of 0, can only be incremented by one, and cannot be
    // decremented or reset. This guarantees that the nonce never overflows.
    unchecked {
      // It is important to do x++ and not ++x here.
      return _pack(key, _nonces[owner][key]++);
    }
  }

  /// @dev Same as `_useNonce` but checking that `nonce` is the next valid for `owner` for specified packed `keyNonce`.
  function _useCheckedNonce(address owner, uint256 keyNonce) internal {
    (uint192 key, ) = _unpack(keyNonce);
    //@>i _useNonce increment nonce by 1 for the key 
    uint256 current = _useNonce(owner, key);
    //@>i check if input keynonc equals to current used nonce
    require(keyNonce == current, InvalidAccountNonce(owner, current));
  }

  /// @dev Pack key and nonce into a keyNonce.
  function _pack(uint192 key, uint64 nonce) private pure returns (uint256) {
    //@>i shift key 64 bit to left and bitwise or with nonce which is 64bit
    return (uint256(key) << 64) | nonce;
  }

  /// @dev Unpack a keyNonce into its key and nonce components.
  function _unpack(uint256 keyNonce) private pure returns (uint192 key, uint64 nonce) {
    //@>i shift keyNonc 64 to the right which brings key to the right and take 192 of it. 
    //@>i take 64 of it which is nonce
    return (uint192(keyNonce >> 64), uint64(keyNonce));
  }
}
