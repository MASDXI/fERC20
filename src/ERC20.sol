// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title fallback ERC20
/// @author sirawt
/// modified from https://github.com/kassandraoftroy/yulerc20
/// modified from https://github.com/Vectorized/solady

contract ERC20 {
    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;


    constructor(string memory name_, string memory symbol_, uint8 decimals_, uint initialSupply) {
        name = name_;
        symbol = symbol_;
        decimals = decimals_;

        // initial balance to deployer address.
        assembly {
            let supply := mul(initialSupply, exp(10, decimals_))
            sstore(totalSupply.slot, supply)

            mstore(0x00, caller())
            mstore(0x20, balanceOf.slot)
            let balanceSlot := keccak256(0x00, 0x40)
            sstore(balanceSlot, supply)

            // emit transfer event.
            mstore(0x00, supply)
            log3(0x00, 0x20, 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef, 0, caller())
        }
    }

    fallback() external payable {
        assembly {
            let selector := shr(224, calldataload(0))

            switch selector
            // transfer(address,uint256)
            case 0xa9059cbb {
                if lt(calldatasize(), 68) { revert(0, 0) }

                let to := calldataload(4)
                let amount := calldataload(36)

                // check to != 0
                if iszero(to) {
                    mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                    mstore(0x04, 0x0000002000000000000000000000000000000000000000000000000000000000)
                    mstore(0x24, 0x0000000d45524332303a20746f207a65726f000000000000000000000000000000)
                    revert(0x00, 0x44)
                }

                // load from balance
                mstore(0x00, caller())
                mstore(0x20, balanceOf.slot)
                let from_balance_$ := keccak256(0x00, 0x40)
                let from_balance := sload(from_balance_$)

                // check sufficient balance
                if lt(from_balance, amount) {
                    mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                    mstore(0x04, 0x0000002000000000000000000000000000000000000000000000000000000000)
                    mstore(0x24, 0x0000000f45524332303a2062616c616e636500000000000000000000000000000000)
                    revert(0x00, 0x44)
                }

                // update from balance
                sstore(from_balance_$, sub(from_balance, amount))

                // load and update to balance
                mstore(0x00, to)
                let to_balance_$ := keccak256(0x00, 0x40)
                let to_balance := sload(to_balance_$)
                sstore(to_balance_$, add(to_balance, amount))

                // emit transfer event.
                mstore(0x00, amount)
                log3(0x00, 0x20, 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef, caller(), to)

                // return true
                mstore(0x00, 1)
                return(0x00, 0x20)
            }
            // approve(address,uint256)
            case 0x095ea7b3 {
                if lt(calldatasize(), 68) { revert(0, 0) }

                let spender := calldataload(4)
                let amount := calldataload(36)

                // check spender != 0
                if iszero(spender) {
                    mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                    mstore(0x04, 0x0000002000000000000000000000000000000000000000000000000000000000)
                    mstore(0x24, 0x0000001045524332303a207a65726f206164647200000000000000000000000000)
                    revert(0x00, 0x44)
                }

                // store allowance
                mstore(0x00, caller())
                mstore(0x20, allowance.slot)
                let owner_$ := keccak256(0x00, 0x40)
                mstore(0x00, spender)
                mstore(0x20, owner_$)
                let allowance_$ := keccak256(0x00, 0x40)
                sstore(allowance_$, amount)

                // emit approval event.
                mstore(0x00, amount)
                log3(0x00, 0x20, 0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925, caller(), spender)

                // return true
                mstore(0x00, 1)
                return(0x00, 0x20)
            }
            // function transferFrom(address,address,uint256) returns (bool)
            case 0x23b872dd {
                if lt(calldatasize(), 100) { revert(0, 0) }

                let from := calldataload(4)
                let to := calldataload(36)
                let amount := calldataload(68)

                // check to != 0
                if iszero(to) {
                    mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                    mstore(0x04, 0x0000002000000000000000000000000000000000000000000000000000000000)
                    mstore(0x24, 0x0000000d45524332303a20746f207a65726f000000000000000000000000000000)
                    revert(0x00, 0x44)
                }

                // check allowance
                mstore(0x00, from)
                mstore(0x20, allowance.slot)
                let from_allowance_$ := keccak256(0x00, 0x40)
                mstore(0x00, caller())
                mstore(0x20, from_allowance_$)
                let allowance_$ := keccak256(0x00, 0x40)
                let current_allowance := sload(allowance_$)

                // check sufficient allowance
                if lt(current_allowance, amount) {
                    mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                    mstore(0x04, 0x0000002000000000000000000000000000000000000000000000000000000000)
                    mstore(0x24, 0x0000001045524332303a20616c6c6f77616e636500000000000000000000000000)
                    revert(0x00, 0x44)
                }

                // update allowance
                sstore(allowance_$, sub(current_allowance, amount))

                // check from balance
                mstore(0x00, from)
                mstore(0x20, balanceOf.slot)
                let from_balance_$ := keccak256(0x00, 0x40)
                let from_balance := sload(from_balance_$)

                // check sufficient balance
                if lt(from_balance, amount) {
                    mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                    mstore(0x04, 0x0000002000000000000000000000000000000000000000000000000000000000)
                    mstore(0x24, 0x0000000f45524332303a2062616c616e636500000000000000000000000000000000)
                    revert(0x00, 0x44)
                }

                // update from balance
                sstore(from_balance_$, sub(from_balance, amount))

                // update to balance
                mstore(0x00, to)
                let to_balance_$ := keccak256(0x00, 0x40)
                let to_balance := sload(to_balance_$)
                sstore(to_balance_$, add(to_balance, amount))

                // emit transfer event.
                mstore(0x00, amount)
                log3(0x00, 0x20, 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef, from, to)

                // return true
                mstore(0x00, 1)
                return(0x00, 0x20)
            }
            // default case as fallback revert.
            default { revert(0, 0) }
        }
    }
}
