// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import "@openzeppelin/contracts/access/Ownable.sol";
import 'lib/solmate/src/tokens/ERC20.sol';


contract FeeManger is Ownable {
    using SafeTransferLib for ERC20;

    event Withdraw(address indexed sender, address indexed token, uint256 amount);
    constructor(){
        owner = msg.sender;
    }

    function withdraw(address token, uint256 amount) external onlyOwner() {
        require(amount > 0);
        require(token != address(0));
        ERC20(token).safeTransfer(msg.sender, amount);
        emit Withdraw(msg.sender, token, amount);
    }

}