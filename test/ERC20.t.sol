// test/ERC20Fallback.t.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import 'forge-std/Test.sol';
import '../src/ERC20.sol';

interface IERC20Fallback {
    function totalSupply() external view returns (uint);
    function balanceOf(address) external view returns (uint);
    function allowance(address, address) external view returns (uint);

    function transfer(address to, uint amount) external returns (bool);
    function approve(address spender, uint amount) external returns (bool);
    function transferFrom(address from, address to, uint amount) external returns (bool);
}

contract ERC20FallbackTest is Test {
    // The contract under test
    address tokenAddr;
    IERC20Fallback token;

    // test accounts
    address deployer = address(this); // test contract deploys the token in setUp
    address alice = address(0xAbcd);
    address bob = address(0xBEEF);
    address charlie = address(0xCAFE);

    uint8 decimals = 18;
    uint initialSupply = 1000; // base units before decimals

    function setUp() public {
        // deploy the contract under test using the source-provided constructor:
        // constructor(string memory name_, string memory symbol_, uint8 decimals_, uint256 supply)
        bytes memory bytecode = type(ERC20).creationCode;
        // Not necessary to use create2 — just deploy directly
        tokenAddr = address(new ERC20('FeToken', 'FE', decimals, initialSupply));
        token = IERC20Fallback(tokenAddr);

        // sanity: deployer = address(this) should have full balance
        uint scaled = initialSupply * (10 ** uint(decimals));
        assertEq(token.totalSupply(), scaled);
        assertEq(token.balanceOf(deployer), scaled);
    }

    function test_transfer_succeeds_and_emits() public {
        uint amount = 100 * (10 ** uint(decimals));
        uint preDeployer = token.balanceOf(deployer);
        uint preBob = token.balanceOf(bob);

        // expect a Transfer event: indexed from, indexed to, value
        vm.expectEmit(true, true, false, true);
        emit Transfer(deployer, bob, amount);
        vm.startSnapshotGas('transfer');
        bool ok = token.transfer(bob, amount);
        vm.stopSnapshotGas();
        assertTrue(ok, 'transfer should return true');

        assertEq(token.balanceOf(deployer), preDeployer - amount);
        assertEq(token.balanceOf(bob), preBob + amount);
    }

    function test_transfer_reverts_insufficientBalance() public {
        // alice has zero tokens, trying to send any amount must revert
        vm.prank(alice);
        vm.expectRevert(); // any revert ok
        token.transfer(bob, 1);
    }

    function test_transfer_reverts_zeroAddress() public {
        uint amount = 1 * (10 ** uint(decimals));
        vm.expectRevert();
        token.transfer(address(0), amount);
    }

    function test_approve_and_transferFrom_flow() public {
        uint amount = 50 * (10 ** uint(decimals));
        vm.prank(deployer);
        // deployer approves alice to spend `amount`
        vm.startSnapshotGas('approve');
        bool ok = token.approve(alice, amount);
        vm.stopSnapshotGas();
        assertTrue(ok, 'approve returned true');
        assertEq(token.allowance(deployer, alice), amount);

        // alice transfers on behalf of deployer -> to bob
        vm.prank(alice);
        vm.startSnapshotGas('transferFrom');
        bool ok2 = token.transferFrom(deployer, bob, amount);
        vm.stopSnapshotGas();
        assertTrue(ok2);

        // allowance should be reduced to zero
        assertEq(token.allowance(deployer, alice), 0);

        // balances updated
        assertEq(token.balanceOf(bob), amount);
    }

    function test_transferFrom_reverts_on_insufficientAllowance() public {
        uint amount = 10 * (10 ** uint(decimals));
        // charlie tries to transferFrom deployer without allowance
        vm.prank(charlie);
        vm.expectRevert();
        token.transferFrom(deployer, charlie, amount);
    }

    function test_transferFrom_reverts_on_insufficientBalance() public {
        // Setup: transfer almost all tokens away from deployer to bob
        uint scaled = initialSupply * (10 ** uint(decimals));
        uint big = scaled - 1; // leave 1 token in deployer
        token.transfer(bob, big);

        // deployer approves alice to spend more than remaining balance
        uint want = 100 * (10 ** uint(decimals));
        token.approve(alice, want);

        // alice tries to transferFrom deployer more than deployer has -> revert
        vm.prank(alice);
        vm.expectRevert();
        token.transferFrom(deployer, alice, want);
    }

    // --- event signature helper so vm.expectEmit compiles cleanly ---
    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
}
