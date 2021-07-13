// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


contract StakingToken is ERC20, ERC20Burnable {
    using SafeERC20 for IERC20;


    constructor() ERC20("StakingToken", "STK") {
        _mint(address(this), 1000000 * 10 ** decimals());
    }

    function drip(address _recipient, uint _amount) public {
		require(_recipient != address(0));
		_transfer(address(this), _recipient, (_amount * 1 ether));
		
	}
}