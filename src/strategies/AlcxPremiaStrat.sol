// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '../interfaces/IAlchemistV2.sol';
import '../interfaces/IPool.sol';
import '../interfaces/IStrategy.sol';
import 'lib/solmate/src/tokens/ERC20.sol';
import 'lib/solmate/src/utils/SafeTransferLib.sol';
import {ERC1155TokenReceiver} from 'lib/solmate/src/tokens/ERC1155.sol';
import "../helpers/SwapHelper.sol";


contract Strategy is IStrategy, ERC1155TokenReceiver{
  using SafeTransferLib for ERC20;
  
  /// CONSTANTS
  address public constant premiaToken = address(0x6399C842dD2bE3dE30BF99Bc7D1bBF6Fa3650E70);
  uint256 public constant maxValue = type(uint256).max;
  uint256 public constant interval = 1 days;
  uint256 public constant fee = 1e5; //10_00_00
  uint256 public constant base = 1e6; //1_00_00_00
  uint256 public lastHarvestTimeStamp;

  /// IMMUTABLES
  IAlchemistV2 public immutable alchemist;
  ICurvePool public immutable curvePool ;
  IPool public immutable premiaPool;
  SwapHelper public immutable swapHelper;

  address public immutable underlying;
  address public immutable debtToken;
  address public immutable alchemistYT;
  address public immutable vault;
  address private immutable feeManager;
  uint256 public immutable reserveLiquidity;
  bool public immutable isCall;


  /// CONSTRUCTOR
  constructor(
    address _vault,
    address _underlying,
    address _alchemist,
    address _alchemistYT,
    address _premiaPool,
    address _swapHelper,
    bool _isCall,
    address _curvePool
  ){
    alchemist = IAlchemistV2(_alchemist);
    alchemistYT = _alchemistYT;
    premiaPool = IPool(_premiaPool);
    vault = _vault;
    underlying = _underlying;
    curvePool = ICurvePool(_curvePool);
    isCall = _isCall;

    lastHarvestTimeStamp = block.timestamp;

    swapHelper = SwapHelper(_swapHelper);
    address _debtToken = IAlchemistV2(_alchemist).debtToken();
    debtToken = _debtToken;

    //APPROVALS
    _setMaxApproval(_underlying, _alchemist); 
    //approve alETH to premiaPool
    _setMaxApproval(_debtToken, _premiaPool);
 
    require(
      IAlchemistV2(_alchemist).isSupportedYieldToken(_alchemistYT)
      , "YIELD_TOKEN_NOT_SUPPORTED"
    );
  }

  function executeStrategy() public override {
    _mintAlTokenAndWriteOptions();
  }

  function unwind(uint256 amount) external override onlyVault(){
    _unwind(amount);
  }

  function closePosition() external override onlyVault(){
    _unwind(maxValue, address(this));

    // clear any oustanding debt after unwinding
    (int256 debt, ) = alchemist.accounts(address(this));
    uint256 pps = alchemist.getUnderlyingTokensPerShare(alchemistYT);
    uint256 sharesToLiquidate;

    if (debt > 0) {
      uint256 _debt = uint256(debt);
      sharesToLiquidate = _debt / pps;
    }
    if (sharesToLiquidate > 0) alchemist.liquidate(alchemistYT, sharesToLiquidate, 0);
    (uint256 shares, ) = alchemist.positions(address(this), alchemistYT);
    if (shares > 0) _withdrawUnderlyingFromAlcx(alchemistYT, shares, 0);
  }

  function transferUnderlyingToVault(uint256 _amount) external override onlyVault(){
    IERC20(underlying).transfer(vault, _amount);
  }


  /// VIEW FUNCTIONS
  function currentValue() external override view returns(uint256){
    (int256 debt, ) = alchemist.accounts(address(this));
    int256 _totalValue = int256(alchemist.totalValue(address(this))) - debt;
    (uint256 totalDeposit,) = premiaPool.getUserTVL(address(this));
    return totalDeposit + uint256(_totalValue);
  }
  
  function _unwind(uint256 _amount) internal {
    uint256 amtBurnt;
    uint256 leftover;
    uint256 availableCredit = _getAvailableCreditToWithdraw();
    // calculate amount to withdraw
    _amount = availableCredit >= _amount ? 0 : (_amount - availableCredit);
    // assume 1:1 with amount deposited into premia pool
    if (_amount > 0){
      uint256 poolAmt = _exitOptionsPool(_amount);
      (int256 debt, ) = alchemist.accounts(address(this));

      // calculate amount of tokens to burn
      if(debt > 0){
        uint256 _debt = uint256(debt);
        uint256 amtToBurn = poolAmt >= _debt ? _debt : poolAmt;
        alchemist.burn(amtToBurn, address(this));
        amtBurnt = amtToBurn;
        leftover = poolAmt - amtBurnt;
      }
    }
    // swap leftover tokens to underlying on curve
    uint256 amtSwapped;
    if(leftover > 0){
      uint256 alTokenBalance = _totalBalance(debtToken);
      amtSwapped = alTokenBalance >= leftover 
      ? SwapHelper.curveSwap( leftover)//swap leftover; 
        : SwapHelper.curveSwap(alTokenBalance);
    }

    uint256 pps = alchemist.getUnderlyingTokensPerShare(alchemistYT);
    uint256 _shares = (amtBurnt + availableCredit) / pps;
    _withdrawUnderlyingFromAlcx(alchemistYT, shares, 0);

    emit Unwind(msg.sender, amtBurnt + availableCredit + amtSwapped);
  }

  function _mintAlTokenAndWriteOptions() internal {
    uint256 amount = _totalBalance(underlying);
    amount = amount - (amount * reserveLiquidity/base);
    uint256 alTokenAmt = _mintAlToken(amount);
    require(alTokenAmt > 0, "TOKEN_AMOUNT_INVALID");
    _writeOptions(alTokenAmt);
  }

  function harvestRewards() external override {
    require(_nextHarvestTimeStamp() <= block.timestamp);
    uint256 amount;
    try premiaPool.claimRewards(isCall) {
      amount = _totalBalance(premiaToken);
      IERC20(premiaToken).transfer(address(swapHelper), amount);
      uint256 amountOut = swapHelper.uniSwap(premiaToken, underlying, amount);
      IERC20(underlying).transferFrom(address(this), feeManager, amountOut * fee/base);
      _resetLastHarvestTimestamp();
    } catch {}

    emit HarvestRewards(amount);
  }

  /// INTERNAL FUNCTIONS
  function _writeOptions(uint256 _amount) internal {
    premiaPool.setBuybackEnabled(true, isCall);
    premiaPool.deposit(_amount, isCall);
  }
  function _exitOptionsPool(uint256 _amount) internal returns(uint256){
    (uint256 totalDeposit,) = premiaPool.getUserTVL(address(this));
    _amount = _amount > totalDeposit ?  totalDeposit : _amount;
    premiaPool.withdraw(
      _amount, 
      isCall
    );
    return _amount;
  }
  function _mintAlToken(uint256 _amount) internal returns(uint256){
    require(_amount > 0);

    alchemist.depositUnderlying(alchemistYT, _amount, address(this), 0); 
    alchemist.mint(_getAvailableCreditToMint(), address(this));
    return _totalBalance(debtToken);
  }

  /// get available credit
  function _getAvailableCreditToMint() internal view returns(uint256){
    (int256 debt, ) = alchemist.accounts(address(this));
    int256 _totalValue = int256(alchemist.totalValue(address(this)) / 2) - debt;
    return uint256(_totalValue);
  }
  
  /// get available interest free credit
  function _getAvailableCreditToWithdraw() internal view returns(uint256){
    (int256 debt, ) = alchemist.accounts(address(this));
    int256 _totalValue;
    if (debt > 0) _totalValue = int256(alchemist.totalValue(address(this)) / 2) - debt ;
    return uint256(_totalValue);
  }

  function _withdrawUnderlyingFromAlcx(
    address _yieldToken, 
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

  function _totalBalance(address _token) internal view returns(uint256){
    return ERC20(_token).balanceOf(address(this));
  }

  function _nextHarvestTimeStamp() internal returns(uint256){
    return lastHarvestTimeStamp + INTERVAL;
  }
  function _resetLastHarvestTimestamp() internal {
    lastHarvestTimeStamp = block.timestamp;
  }

  function _setMaxApproval(address _token, uint256 _to) internal {
    ERC20(_token).safeApprove(_to, MAX_VALUE);
  }

  /// MODIFIERS
  modifier onlyVault(){
    require(msg.sender == vault, "ONLY_VAULT");
    _;
  }

  /// EVENTS
  event ExecuteStrategy(address indexed vault, uint256 amountDeposited);
  event HarvestRewards(uint256 rewardsHarvested);
  event unwind(address indexed vault, uint256 amount);
}

