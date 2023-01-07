// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "solmate/tokens/ERC20.sol";
import "solmate/utils/SafeTransferLib.sol";
import "solmate/tokens/ERC1155.sol";

import "../interfaces/alchemix/IAlchemistV2.sol";
import "../interfaces/premia/IPremiaPool.sol";
import "../interfaces/IStrategy.sol";
import "../helpers/SwapHelper.sol";
import "../utils/Constants.sol";


contract AlcxPremiaStrat is IStrategy, Pausable, ERC1155TokenReceiver {
  using SafeTransferLib for ERC20;
  using SafeCast for uint256;
  using SafeCast for int256;

  /// IMMUTABLES
  IAlchemistV2 public immutable alchemist;
  ICurvePool public immutable curvePool ;
  IPool public immutable premiaPool;
  SwapHelper public immutable swapHelper;

  bool public immutable isCall;
  address public immutable premiaToken;
  address public immutable underlying;
  address public immutable alcxDebtToken;
  address public immutable alchemistYT;
  address public immutable vault;
  address public immutable feeManager;
  uint256 public immutable harvestFee;
  // uint256 public immutable curveIndex;

  uint256 public lastHarvestTimeStamp;

  /// EVENTS
  event Deposit(uint256 amount);
  event Withdraw(uint256 amount);
  event WithdrawAll();
  event FeesClaimed(uint256 _amount);
  event ExecuteStrategy();
  event HarvestRewards(uint256 rewardsHarvested);

  /// MODIFIERS
  modifier onlyVault(){
    require(msg.sender == vault, Errors.ONLY_VAULT);
    _;
  }


  /// CONSTRUCTOR
  constructor(
    address _vault,
    address _underlying,
    address _alchemist,
    address _alchemistYieldToken,
    address _premiaPool,
    address _premiaToken,
    address _feeManager,
    address _swapHelper,
    address _curvePool,
    uint256 _harvestFee,
    bool _isCall
  ){
    alchemist = IAlchemistV2(_alchemist);
    alchemistYT = _alchemistYieldToken;
    premiaPool = IPool(_premiaPool);
    vault = _vault;
    underlying = _underlying;
    curvePool = ICurvePool(_curvePool);
    isCall = _isCall;
    harvestFee = _harvestFee;
    premiaToken = _premiaToken;
    feeManager = _feeManager;

    lastHarvestTimeStamp = block.timestamp;

    swapHelper = SwapHelper(_swapHelper);
    address _debtToken = IAlchemistV2(_alchemist).debtToken();
    alcxDebtToken = _debtToken;

    // APPROVALS
    // approve underlying token to alchemist contract
    _setMaxApproval(_underlying, _alchemist); 
    // approve alETH to premiaPool
    _setMaxApproval(_debtToken, _premiaPool);
 
    require(
      IAlchemistV2(_alchemist).isSupportedYieldToken(_alchemistYieldToken),
      Errors.YT_NOT_SUPPORTED
    );
  }

  ///@dev deposit underlying balance into strategy
  function deposit() external override onlyVault() whenNotPaused(){
    // total balance of underlying
    uint256 amount = _totalBalance(underlying);
    _mintAlTokenAndWriteOptions(amount);

    emit Deposit(amount);
  }

  ///@notice withdraw `amount` from strategy
  ///@param amount amount to withdraw
  function withdraw(uint256 amount) external override onlyVault() whenNotPaused(){
    require(amount != Constants.ZERO, Errors.INVALID_AMOUNT);
    _unwind(amount);

    emit Withdraw(amount);
  }

  ///@notice withdraw all amount from strategy(close all open positions)
  function withdrawAll() external override onlyVault() whenNotPaused(){
    _unwind(Constants.MAX_VALUE);

    // clear any oustanding debt after unwinding
    (int256 debt, ) = alchemist.accounts(address(this));
    uint256 pps = alchemist.getUnderlyingTokensPerShare(alchemistYT);
    uint256 sharesToLiquidate;

    if (debt > 0) {
      sharesToLiquidate = debt.toUint256() / pps;
    }
    if (sharesToLiquidate > Constants.ZERO) alchemist.liquidate(alchemistYT, sharesToLiquidate, Constants.ZERO);
    (uint256 shares, ) = alchemist.positions(address(this), alchemistYT);
    if (shares > Constants.ZERO) _withdrawUnderlyingFromAlcx(shares, Constants.ZERO);

    emit WithdrawAll();
  }
  
  ///@notice harvest rewards
  ///@dev claim premia token rewards and swap to underlying
  function harvestRewards() external override {
    require(_nextHarvestTimeStamp() <= block.timestamp, Errors.CANNOT_HARVEST);
    uint256 premiaBal;
    try premiaPool.claimRewards(isCall) {
      premiaBal = _totalBalance(premiaToken);
      // transfer contract premia token balance to swap helper
      ERC20(premiaToken).transfer(address(swapHelper), premiaBal);
      // swap premia token for underlying
      uint256 amountOut = swapHelper.swapTokenMultiHopWeth(premiaToken, underlying);
      //trnasfer fee to fee manager
      _transferFee(amountOut * harvestFee/Constants.BASE);
      // harvest timestamp
      _resetLastHarvestTimestamp();
    } catch {}

    emit HarvestRewards(premiaBal);
  }

  ///@notice pause strategy
  function pause() external onlyVault(){
    _pause();
  }

  ///@notice unpause strategy
  function unpause() external onlyVault(){
    _unpause();
  }

  ///@notice get balance of underlying
  function balance() public override view returns(uint256){
        return _totalBalance(underlying);
  }

  ///@notice current strategy value - debt
  function currentValue() external override view returns(uint256){
    (int256 debt, ) = alchemist.accounts(address(this));
    int256 _totalValue = alchemist.totalValue(address(this)).toInt256() - debt;
    (uint256 totalDeposit,) = premiaPool.getUserTVL(address(this));

    return totalDeposit + _totalValue.toUint256();
  }

  function name() external view override returns(string memory){
    return string(abi.encodePacked("AlcxPremia ", ERC20(underlying).name(), " Strat"));
  }

  /// INTERNAL FUNCTIONS

  ///@notice unwind position to withdraw `_amount` of underlying
  ///@dev withdraw all by setting `_amount` to max value
  ///@param _amount amount to withdraw
  function _unwind(uint256 _amount) internal {
    uint256 amtBurnt;
    uint256 leftover;
    uint256 availableCredit = _getAvailableCreditToWithdraw();
    // calculate amount to withdraw
    _amount = availableCredit >= _amount ? Constants.ZERO : (_amount - availableCredit);
    // assume 1:1 with amount deposited into premia pool
    if (_amount > Constants.ZERO){
      uint256 poolAmt = _exitOptionsPool(_amount);
      (int256 debt, ) = alchemist.accounts(address(this));

      // calculate amount of tokens to burn
      if(debt > 0){
        uint256 _debt = debt.toUint256();
        uint256 amtToBurn = Math.min(_debt, poolAmt); //math.min
        alchemist.burn(amtToBurn, address(this));
        amtBurnt = amtToBurn;
        leftover = poolAmt - amtBurnt;
      }
    }
    // swap leftover tokens to underlying on curve
    uint256 amtOut;
    if(leftover > Constants.ZERO){
      uint256 alTokenBalance = _totalBalance(alcxDebtToken);
      alTokenBalance >= leftover 
        ? _transfer(alcxDebtToken, address(swapHelper), leftover)
        : _transfer(alcxDebtToken, address(swapHelper), alTokenBalance);
      amtOut = swapHelper.curveSwap(alcxDebtToken,  curvePool);
    }

    uint256 pps = alchemist.getUnderlyingTokensPerShare(alchemistYT);
    uint256 _shares = (amtBurnt + availableCredit) / pps;
    _withdrawUnderlyingFromAlcx(_shares, Constants.ZERO);

  }

  ///@notice deposit into alchemix, max borrow and deposit into premia options pool
  function _mintAlTokenAndWriteOptions(uint256 amount) internal {
    // mint alchemix token
    uint256 alTokenAmt = _mintAlToken(amount);
    require(alTokenAmt > Constants.ZERO, Errors.INVALID_AMOUNT);
    _writeOptions(alTokenAmt);
  }

  ///@dev deposit `amount` into premia pool (write options)
  ///@param _amount amount to deposit into premia pool
  function _writeOptions(uint256 _amount) internal {
    premiaPool.setBuybackEnabled(true, isCall);
    premiaPool.deposit(_amount, isCall);
  }

  ///@dev withdraw `amount` from premia pool
  ///@param _amount amount to withdraw from premia pool
  function _exitOptionsPool(uint256 _amount) internal returns(uint256){
    (uint256 totalDeposit,) = premiaPool.getUserTVL(address(this));
    uint256 _amountToWithdraw = Math.min(_amount, totalDeposit);
    // withdraw from premia pool
    premiaPool.withdraw(_amountToWithdraw, isCall);
    return _amountToWithdraw;
  }

  ///@dev deposit into alchemix and mint debt token (enter short position)
  ///@param _amount amount of debt token(altoken) to mint
  ///@return uint256 balance of altoken
  function _mintAlToken(uint256 _amount) internal returns(uint256){
    require(_amount > Constants.ZERO, Errors.INVALID_AMOUNT);
    // deposit underlying token into alchemix
    alchemist.depositUnderlying(alchemistYT, _amount, address(this), Constants.ZERO); 
    alchemist.mint(_getAvailableCreditToMint(), address(this));

    return _totalBalance(alcxDebtToken);
  }

  ///@dev get available credit that can be minted from alcx position
  function _getAvailableCreditToMint() internal view returns(uint256){
    (int256 debt, ) = alchemist.accounts(address(this));
    int256 _totalValue = alchemist.totalValue(address(this)).toInt256() / 2 - debt;
    return _totalValue.toUint256();
  }
  
  ///@dev get available credit that can be burnt from alcx position
  function _getAvailableCreditToWithdraw() internal view returns(uint256){
    (int256 debt, ) = alchemist.accounts(address(this));
    int256 _totalValue;
    if (debt > 0) _totalValue = alchemist.totalValue(address(this)).toInt256() / 2 - debt;
    return _totalValue.toUint256();
  }

  ///@dev withdraw underlying from alchemix
  ///@param _shares shares to withdraw
  ///@param minAmountOut minimum output amount
  function _withdrawUnderlyingFromAlcx(
    uint256 _shares, 
    uint256 minAmountOut
  ) internal {
    alchemist.withdrawUnderlying(
      alchemistYT, 
      _shares, 
      address(this),
      minAmountOut
    );     
  }

  ///@notice transfer fee to fee manager contract
  ///@param _amount amount to transfer
  function _transferFee(uint256 _amount) internal {
    _transfer(underlying, feeManager, _amount);

    emit FeesClaimed(_amount);
  }

  ///@notice transfer erc20 token to `_to` 
  ///@param _token erc20 token
  ///@param _to token reciever
  ///@param _amount amount to transfer
  function _transfer(address _token, address _to, uint256 _amount) internal {
    ERC20(_token).transfer(_to, _amount);
  }

  ///@notice returns total balance of `_token`
  ///@param _token erc20 token address
  function _totalBalance(address _token) internal view returns(uint256){
    return ERC20(_token).balanceOf(address(this));
  }

  ///@notice min. next harvest timestamp
  function _nextHarvestTimeStamp() internal view returns(uint256){
    return lastHarvestTimeStamp + Constants.HARVEST_INTERVAL;
  }

  ///@dev reset next harvest timestamp to `now`
  function _resetLastHarvestTimestamp() internal {
    lastHarvestTimeStamp = block.timestamp;
  }

  ///@notice set mamximum approval for `_token`
  function _setMaxApproval(address _token, address _to) internal {
    ERC20(_token).safeApprove(_to, Constants.MAX_VALUE);
  }
}

