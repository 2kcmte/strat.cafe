// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
interface IStrategy {

  function name() external view returns(string memory);

  function balance() external view returns(uint256);

  function currentValue() external view returns(uint256);

  function deposit() external;

  function withdraw(uint256) external;

  function withdrawAll() external;

  function harvestRewards() external;
  
}
