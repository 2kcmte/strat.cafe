// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
interface IStrategy {
  function currentValue() external view returns(uint256);
  function closePosition() external;
  function harvestRewards() external;
  function execute() external;
  function unwind(uint256 amount) external;
  function transferUnderlyingToVault(uint256 _amount) external;
}
