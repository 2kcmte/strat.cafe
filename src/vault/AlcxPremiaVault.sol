// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import "solmate/mixins/ERC4626.sol";
import "solmate/auth/Auth.sol";
import "../helpers/FeeManager.sol";
import "../interfaces/IStrategy.sol";
import "../utils/Constants.sol";
import "../utils/Errors.sol";

contract Vault is ERC4626, Auth {

  uint256 public depositCap;
  uint256 public totalDeposit;
  ERC20 public immutable underlying;

  uint256 public managementFee;
  uint256 public vaultLiquidityTarget;
  FeeManager public feeRecipient;

  IStrategy public strategy;

  constructor(
    ERC20 _underlying
  ) 
  ERC4626(
    _underlying, 
    string(abi.encodePacked("AlcxPremiaStrat ", _underlying.name(), " Vault")),
    string(abi.encodePacked("ap", _underlying.symbol()))
  )
  Auth(Auth(msg.sender).owner(), Auth(msg.sender).authority())
  {
    underlying = _underlying;
  }

  function totalAssets() public view override returns(uint256){
    return _vaultLiquidity() + strategy.currentValue();
  }

  function _vaultLiquidity() public view returns(uint256){
    return underlying.balanceOf(address(this));
  }

  function setFeeRecipient(address _feeRecipient) public requiresAuth {
    feeRecipient = FeeManager(_feeRecipient);
  }

  function depositIntoStrategy(uint256 _amount) public {
    require(_amount != Constants.ZERO, Errors.INVALID_AMOUNT);
    _depositUnderlyingIntoStrategy(_amount);
  }

  function _depositUnderlyingIntoStrategy(uint256 _amount) internal {
    underlying.transfer(address(strategy), _amount);
    strategy.deposit();
  }

  function setStrategy(address _strategy) public requiresAuth {
    strategy = IStrategy(_strategy);
  }

  function setCap(uint256 _cap) public requiresAuth {
    uint256 previousCap = depositCap;
    require(_cap > previousCap, Errors.CAP_EXCEEDED);
    depositCap = _cap;
  }

  function claimFees() public {}

  function beforeWithdraw(uint256 assets, uint256) internal override {
        // Retrieve underlying tokens from strategies.
        _withdrawUnderlying(assets);
    }

  function afterDeposit(uint256 assets, uint256) internal view override {
    if(depositCap > 0){
      require(totalDeposit + assets <= depositCap, Errors.CAP_EXCEEDED);
    }
  }

  function _withdrawUnderlying(uint256 _amount) internal {

  }
  
  function harvest() external {
    
  }
 
}
