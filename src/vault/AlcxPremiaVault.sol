// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import "solmate/mixins/ERC4626.sol";
import "./IStrategy.sol";

contract Vault is ERC4626 {

  uint256 public constant BASE = 10000;
  uint256 public cap;
  address public owner;
  uint256 public fee;
  address public feeRecipient;
  uint256 lockedAsset;
  mapping(address => uint256) pendingWithdrawals;
  IStrategy public strategy;


  constructor(
    ERC20 _asset,
    string memory name,
    string memory symbol,
    address _owner,
    address _feeRecipient
  ) ERC4626(_asset, name, symbol){
    owner = _owner;
    feeRecipient = _feeRecipient;
  }


  function totalAssets() public view override returns(uint256){
    return _pendingDeposits() + strategy.currentValue();
  }

  function _pendingDeposits() public view returns(uint256){
    return asset.balanceOf(address(this));
  }

  function deposit(uint256 _asset, address reciever) public override returns(uint256){
    if(cap > 0 && _asset + totalAssets() > cap) revert("CAP_EXCEEDED");
    return super.deposit(_asset - fee, reciever);
  }
  function mint(uint256 _shares, address receiver) public override returns (uint256){
    if(cap > 0 && previewMint(_shares)  + totalAssets() > cap) revert("CAP_EXCEEDED");
    return super.mint(_shares, receiver);
  }
  function withdraw(uint256 assets, address receiver, address _owner) public override returns (uint256){
    if(_pendingDeposits() < assets) revert("NO_LIQUIDITY");
    return super.withdraw(assets, receiver, _owner);
  }
  function redeem(uint256 shares, address receiver, address _owner) public override returns (uint256){
    if(_pendingDeposits() < previewRedeem(shares)) revert("NO_LIQUIDITY");
    return super.redeem(shares, receiver, _owner);
  }
  function depositIntoStrategy(uint256 _amount) public {
    asset.transfer(address(strategy), _amount);
    strategy.mintAlTokenAndWriteOptions();
    uint256 _fee = _amount * (fee / BASE);
    _mint(address(this), _fee);
  }
  function withdrawFromStrategy(uint256 _amount) internal {
    strategy.withdrawUnderlying(_amount);
  }
  function closeVaultPosition() public {
    strategy.closePosition();
  }
  function harvestStrategyRewards() external {
    uint256 _before = _totalDebt();
    strategy.harvestRewards();
    uint256 _after = _totalDebt();
    uint256 _fee = _before - _after * (fee / BASE);
    _mint(address(this), _fee);
  }

  function claimFees() external {
    uint256 amount = asset.balanceOf(address(this));
    asset.transfer(feeRecipient, amount);
  }
  function setCap(uint256 _cap) public {
    cap = _cap;
  }
  function setStrategy(address _strategy) public {
    strategy = IStrategy(_strategy);
  }

  function _totalDebt() internal view returns (uint256) {
    return strategy.currentValue();
  }

}
