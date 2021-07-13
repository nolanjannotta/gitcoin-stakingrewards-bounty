// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RewardToken1 is ERC20 {
    constructor() ERC20("RewardToken1", "RWD1") {
        _mint(address(this), 1000000 * 10 ** decimals());
    }
}