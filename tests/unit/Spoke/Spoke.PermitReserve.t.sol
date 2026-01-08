// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';
import {console} from 'forge-std/console.sol'; 

contract SpokePermitReserveTest is SpokeBase {
  function test_permitReserve_revertsWith_ReserveNotListedIn() public {
    //uint256 unlistedReserveId = vm.randomUint(spoke1.getReserveCount() + 1, UINT256_MAX);
    uint256 unlistedReserveId = spoke1.getReserveCount() + 1;
    console.log("reserve count:", spoke1.getReserveCount());
    console.log("unlisted reserve id:", unlistedReserveId);

    vm.expectRevert(ISpoke.ReserveNotListed.selector);
    vm.prank(vm.randomAddress());
    spoke1.permitReserve(
      unlistedReserveId,
      vm.randomAddress(), //@>i user
      vm.randomUint(),//@>i value
      vm.randomUint(),//@>i deadline
      uint8(vm.randomUint()),//@>i v
      bytes32(vm.randomUint()),//@>i r
      bytes32(vm.randomUint())//@>i s
    );
  }

  function test_permitReserve_forwards_correct_call() public {
    uint256 reserveId = _daiReserveId(spoke1);
    address owner = vm.randomAddress();
    address spender = address(spoke1);
    uint256 value = vm.randomUint();
    uint256 deadline = vm.randomUint();
    uint8 v = uint8(vm.randomUint());
    bytes32 r = bytes32(vm.randomUint());
    bytes32 s = bytes32(vm.randomUint());

    console.log("Reserve ID:", reserveId);
    console.log("Owner:", owner);
    console.log("Spender:", spender);
    console.log("Value:", value);
    console.log("Deadline:", deadline);
    console.log("Signature v:", v);

    vm.expectCall(
      address(tokenList.dai),
      abi.encodeCall(TestnetERC20.permit, (owner, spender, value, deadline, v, r, s)),
      1 //@>i expect exactly 1 call
    );
    address caller = vm.randomAddress();
    console.log("Calling permitReserve from:", caller);
    vm.prank(caller);
    spoke1.permitReserve(reserveId, owner, value, deadline, v, r, s);
    //@>i token.permit(owner, spender, ...) is called inside spoke.permitReserve(...)
  }

  function test_permitReserve_ignores_permit_reverts() public {
    //@>i simulate a token that does not support permit or reverts for some reason and spoke IGNORES the failure
    //@>i this mocks the call to token.permit(...) to always revert for target address(tokenList.dai)
    vm.mockCallRevert(address(tokenList.dai), TestnetERC20.permit.selector, vm.randomBytes(64));

    vm.prank(vm.randomAddress());
    spoke1.permitReserve(
      _daiReserveId(spoke1),
      vm.randomAddress(),
      vm.randomUint(),
      vm.randomUint(),
      uint8(vm.randomUint()),
      bytes32(vm.randomUint()),
      bytes32(vm.randomUint())
    );
  }

  function test_permitReserve() public {
    (address user, uint256 userPk) = makeAddrAndKey('user');
    console.log("User:", user);
    uint256 initialAllowance = tokenList.dai.allowance(user, address(spoke1));
    assertEq(initialAllowance, 0);
    console.log("- Initial allowance for Spoke:", initialAllowance);

    EIP712Types.Permit memory params = EIP712Types.Permit({
      owner: user,
      spender: address(spoke1),
      value: 100e18,
      deadline: vm.randomUint(1, MAX_SKIP_TIME),
      nonce: tokenList.dai.nonces(user)
    });
    vm.warp(params.deadline - 1);
    console.log("- Permit params:");
    console.log("  Owner:", params.owner);
    console.log("  Spender:", params.spender);
    console.log("  Value:", params.value);
    console.log("  Deadline:", params.deadline);
    console.log("  Nonce:", params.nonce);

    bytes32 digest = _getTypedDataHash(tokenList.dai, params);
      // console.log("- EIP-712 digest:", bytes32ToString(digest));

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);
    console.log("- Signature components: v=%d, r=..., s=...", v);

    vm.expectEmit(address(tokenList.dai));
    emit IERC20.Approval(user, address(spoke1), params.value);
    
    address random_user = vm.randomAddress();
    vm.prank(random_user);
    console.log("Calling permitReserve from random user: ", random_user);
 
    spoke1.permitReserve(_daiReserveId(spoke1), user, params.value, params.deadline, v, r, s);

    uint256 finalAllowance = tokenList.dai.allowance(user, address(spoke1));
    console.log("- Final allowance for Spoke:", finalAllowance);
    assertEq(finalAllowance, params.value);

   }



  
  
  // Missing critical test cases:
    function test_permitReserve_frontrunning() public {
        // 1. User signs permit
        // 2. Malicious actor tries to use permit before intended transaction
        // 3. Should fail or be protected
        (address user, uint256 userPk) = makeAddrAndKey('user');
        address attacker = makeAddr('attacker');

        console.log("User:", user);
        console.log("Attacker:", attacker); 
        console.log("spoke1 address:", address(spoke1));
        console.log("Dai address:", address(tokenList.dai));

        uint256 user_dai_balance = 1000e18;
        deal(address(tokenList.dai), user, user_dai_balance);
        console.log("User DAI balance:", user_dai_balance);

        uint256 initialAllowance = tokenList.dai.allowance(user, address(spoke1));
        assertEq(initialAllowance, 0);
        console.log("- Initial allowance for Spoke:", initialAllowance);

        console.log("=== user create a permit signature ===");
        uint256 permit_amount = 500e18;
        uint256 deadline = block.timestamp + 1 days;
        uint256 nonce = tokenList.dai.nonces(user);
         bytes32 domain_separator = tokenList.dai.DOMAIN_SEPARATOR();
        bytes32 digest = keccak256(abi.encodePacked(
           "\x19\x01",
           domain_separator,
           keccak256(abi.encode(
               keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
               user,
               address(spoke1),
               permit_amount,
               nonce,
               deadline
           ))
        ));
      //@>i user signs the digest
      (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);
        console.log("- Signature components: v=%d, r=..., s=...", v);
      console.log('user signs the digest');

      console.log("=== attacker frontruns user and uses the permit and calls permitReserve for the user ===");
       vm.prank(attacker);
      spoke1.permitReserve(_daiReserveId(spoke1), user, permit_amount, deadline, v, r, s);
 
      uint256 allowance_after_attack = tokenList.dai.allowance(user, address(spoke1));
      console.log("-  allowance for Spoke after attacker used permit:", allowance_after_attack);

      require(allowance_after_attack == permit_amount);

       // User tries to execute permitReserve (should fail)
 
        vm.prank(user);
        console.log("=== user now calls permitReserve ===");
        spoke1.permitReserve(_daiReserveId(spoke1), user, permit_amount, deadline, v, r, s);
        uint256 allowanceAfterUserCall = tokenList.dai.allowance(user, address(spoke1));
        console.log("Allowance after user calls permitReserve:", allowanceAfterUserCall);
 
     }

    function test_permitReserve_expiredSignature() public {
        // Test with deadline < block.timestamp
        // Should revert (but actually might not due to try/catch!)
    }

    function test_permitReserve_wrongSpender() public {
        // What if spender in signature is not Spoke contract?
        // Token should reject but test should verify
    }
    function test_permitReserve_replayAttack() public {
        // Use same signature twice
        // Second use should fail due to nonce increment
    }
}
