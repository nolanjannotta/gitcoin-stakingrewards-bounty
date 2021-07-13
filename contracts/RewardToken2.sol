// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RewardToken2 is ERC20 {
    constructor() ERC20("RewardToken2", "RWD2") {
        _mint(address(this), 1000000 * 10 ** decimals());
    }
}