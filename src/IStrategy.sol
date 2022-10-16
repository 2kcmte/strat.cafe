// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IStrategy {
  function unwind() external;
  function currentValue() external returns(uint256);

  function closePosition() internal;

}
