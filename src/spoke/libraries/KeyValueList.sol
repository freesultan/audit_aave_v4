// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;
/*@>i only called in spoke contract 
### Overview
This is a Solidity library called `KeyValueList` that efficiently packs key-value pairs into a single `uint256` array for storage and manipulation. It uses bit manipulation to store a 32-bit key and a 224-bit value in one word, enabling compact representation of lists. The library supports initialization, addition, retrieval, and sorting of these pairs.

**What it does**: It provides a memory-based list structure for key-value pairs, with functions to pack/unpack data, add elements, get elements, and sort by key (ascending) with value descending on ties. Uninitialized entries default to (0,0) and sort to the end.

**Use cases**: Useful in DeFi protocols like Aave for managing ordered lists of assets, rates, or priorities (e.g., sorting reserves by priority or interest rates). It optimizes gas by packing data into fewer slots, ideal for on-chain computations needing sorted key-value data without external storage.

**Security considerations**: 
- Data size limits prevent overflow (key < 2^32-1, value < 2^224-1); exceeding causes revert.
- Pure functions ensure no state changes, reducing reentrancy risks.
- Sorting relies on OpenZeppelin's `Arrays.sort`, which is battle-tested but assumes correct comparator.
- Uninitialized data (0) is handled gracefully, but misuse (e.g., adding invalid indices) could lead to out-of-bounds errors.
- No access controls; assumes caller handles permissions.
- Gas efficiency is good, but large lists may hit block limits.

### Functions and Constants List
**Constants**:
- `_KEY_BITS`: 32 (bits for key).
- `_VALUE_BITS`: 224 (bits for value).
- `_MAX_KEY`: (1 << 32) - 1 (max key value).
- `_MAX_VALUE`: (1 << 224) - 1 (max value).
- `_KEY_SHIFT`: 256 - 32 = 224 (shift amount for key in packing).

**Functions**:
- `init(uint256 size)`: Allocates a new list.
- `length(List memory self)`: Returns list length.
- `add(List memory self, uint256 idx, uint256 key, uint256 value)`: Adds a packed pair at index.
- `get(List memory self, uint256 idx)`: Retrieves unpacked pair at index.
- `sortByKey(List memory self)`: Sorts list by key ascending, value descending on ties.
- `pack(uint256 key, uint256 value)`: Packs key-value into uint256.
- `unpackKey(uint256 data)`: Unpacks key from packed data.
- `unpackValue(uint256 data)`: Unpacks value from packed data.
- `unpack(uint256 data)`: Unpacks both key and value.
- `gtComparator(uint256 a, uint256 b)`: Greater-than comparator for sorting.

### Function Descriptions
- `init(uint256 size)`: Creates a `List` with an internal array of the given size. Pure, returns memory struct.
- `length(List memory self)`: Returns the array length. Pure, no side effects.
- `add(List memory self, uint256 idx, uint256 key, uint256 value)`: Checks bounds, packs key-value, and stores at index. Reverts on size exceedance.
- `get(List memory self, uint256 idx)`: Unpacks and returns key-value at index. Returns (0,0) for uninitialized.
- `sortByKey(List memory self)`: Sorts the array in descending order using the packed values (inverted key ensures ascending key order). Uses OpenZeppelin's sort.
- `pack(uint256 key, uint256 value)`: Computes `(_MAX_KEY - key) << 224 | value`. Assumes bounds checked.
- `unpackKey(uint256 data)`: Extracts key as `_MAX_KEY - (data >> 224)`.
- `unpackValue(uint256 data)`: Extracts value as `data & ((1 << 224) - 1)`.
- `unpack(uint256 data)`: If data is 0, returns (0,0); else calls unpackKey and unpackValue.
- `gtComparator(uint256 a, uint256 b)`: Returns `a > b`, used for descending sort.
*/
import {Arrays} from 'src/dependencies/openzeppelin/Arrays.sol';
 /// @title KeyValueList Library
/// @author Aave Labs
/// @notice Library to pack key-value pairs in a list.
/// @dev The `sortByKey` helper sorts by ascending order of the `key` & in case of collision by descending order of the `value`.
/// @dev This is achieved by sorting the packed `key-value` pair in descending order, but storing the invert of the `key` (ie `_MAX_KEY - key`).
/// @dev Uninitialized keys are returned as (key: 0, value: 0) and are placed at the end of the list after sorting.
library KeyValueList {
  //@>i relies on OpenZeppelin's `Arrays.sort`
  /// @notice Thrown when adding a key which can't be stored in `_KEY_BITS` or value in `_VALUE_BITS`.
  error MaxDataSizeExceeded();

  struct List {
    uint256[] _inner;
  }

  uint256 internal constant _KEY_BITS = 32;
  uint256 internal constant _VALUE_BITS = 224;
  uint256 internal constant _MAX_KEY = (1 << _KEY_BITS) - 1;//@>i this means: (100...00) - 1 = 01111...1111 means 0 and 32 of 1
  uint256 internal constant _MAX_VALUE = (1 << _VALUE_BITS) - 1;//@>i 224 of 1 : 11...111
  uint256 internal constant _KEY_SHIFT = 256 - _KEY_BITS;//@>i 224

  /// @notice Allocates memory for a KeyValue list of `size` elements.
  function init(uint256 size) internal pure returns (List memory) {
    return List(new uint256[](size));
  }

  /// @notice Returns the length of the list.
  function length(List memory self) internal pure returns (uint256) {
    return self._inner.length;
  }

  /// @notice Inserts packed `key`, `value` at `idx`. Reverts if data exceeds maximum allowed size.
  /// @dev Reverts if `key` equals or exceeds the `_MAX_KEY` value and reverts if `value` equals or exceeds the `_MAX_VALUE` value.
  function add(List memory self, uint256 idx, uint256 key, uint256 value) internal pure {
    require(key < _MAX_KEY && value < _MAX_VALUE, MaxDataSizeExceeded());
    self._inner[idx] = pack(key, value);
  }

  /// @notice Returns the key-value pair at the given index.
  /// @dev Uninitialized keys are returned as (key: 0, value: 0).
  function get(List memory self, uint256 idx) internal pure returns (uint256, uint256) {
    return unpack(self._inner[idx]);
  }

  /// @notice Sorts the list in-place by ascending order of `key`, and descending order of `value` on collision.
  /// @dev All uninitialized keys are placed at the end of the list after sorting.
  /// @dev Since `key` is in the MSB, we can sort by the key by sorting the array in descending order
  /// (so the keys are in ascending order when unpacking, due to the inversion when packed).
  function sortByKey(List memory self) internal pure {
    Arrays.sort(self._inner, gtComparator);
  }

  /// @notice Packs a given `key`, `value` pair into a single word.
  /// @dev Bound checks are expected to be done before packing.
  function pack(uint256 key, uint256 value) internal pure returns (uint256) {
    return ((_MAX_KEY - key) << _KEY_SHIFT) | value;
  }

  /// @notice Unpacks `key` from a previously packed word containing `key` and `value`.
  /// @dev The key is stored in the most significant bits of the word.
  function unpackKey(uint256 data) internal pure returns (uint256) {
    return _MAX_KEY - (data >> _KEY_SHIFT);
  }

  /// @notice Unpacks `value` from a previously packed word containing `key` and `value`.
  /// @dev The value is stored in the least significant bits of the word.
  function unpackValue(uint256 data) internal pure returns (uint256) {
    return data & ((1 << _KEY_SHIFT) - 1);
  }

  /// @notice Unpacks both `key` and `value` from a previously packed word containing `key` and `value`.
  /// @dev Uninitialized keys are returned as (key: 0, value: 0).
  /// @param data The packed word containing `key` and `value`.
  function unpack(uint256 data) internal pure returns (uint256, uint256) {
    if (data == 0) return (0, 0);
    return (unpackKey(data), unpackValue(data));
  }

  /// @notice Comparator function performing greater-than comparison.
  /// @return True if `a` is greater than `b`.
  function gtComparator(uint256 a, uint256 b) internal pure returns (bool) {
    return a > b;
  }
}
