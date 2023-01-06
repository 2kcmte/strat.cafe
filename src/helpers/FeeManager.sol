// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import "@openzeppelin/contracts/access/Ownable.sol";
import "solmate/utils/SafeTransferLib.sol";
import "solmate/tokens/ERC20.sol";
import "../utils/Constants.sol";
import "../utils/Errors.sol";

contract FeeManager is Ownable {
    using SafeTransferLib for ERC20;

    event Withdraw(address indexed sender, address indexed token, uint256 amount);

    constructor() Ownable() {}
 
    function withdraw(address token, uint256 amount, address to) external onlyOwner(){
        require(amount > Constants.ZERO, Errors.INVALID_AMOUNT);
        require(token != Constants.ADDRESS_ZERO && to != Constants.ADDRESS_ZERO, Errors.INVALID_ADDRESS);

        ERC20(token).safeTransfer(to, amount);

        emit Withdraw(to, token, amount);
    }

}