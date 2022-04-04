pragma solidity ^0.8.13;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockDAI is ERC20 {
    constructor() ERC20("MockDAI", "MockDAI") {}
    
    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }
}