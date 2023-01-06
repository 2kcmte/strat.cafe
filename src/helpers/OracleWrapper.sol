// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "solmate/utils/FixedPointMathLib.sol";
import "solmate/tokens/ERC20.sol";
import "../interfaces/oracle/IStaticOracle.sol";
import "../utils/Constants.sol";

contract OracleWrapper {
  using FixedPointMathLib for uint256;
  using SafeCast for uint256;

  IStaticOracle public immutable uniV3Oracle;
  uint256 public immutable timePeriod;

  struct Token {
    address tokenAddress;
    bool hasWethPair;
    bool hasUsdcPair;
  }

  constructor(address _uniV3Oracle, uint256 _period){
    uniV3Oracle = IStaticOracle(_uniV3Oracle);
    timePeriod = _period;
  }

  function getQuoteAmount(address _quoteToken, address _baseToken, uint256 _baseAmount) external view returns(uint256){
    uint256 decimals = ERC20(_quoteToken).decimals();
    Token memory _quoteToken_;
    _quoteToken_.tokenAddress = _quoteToken;
    _quoteToken_.hasUsdcPair = uniV3Oracle.isPairSupported(_quoteToken, Constants.USDC);
    _quoteToken_.hasWethPair = uniV3Oracle.isPairSupported(_quoteToken, Constants.WETH);

    Token memory _baseToken_;
    _baseToken_.tokenAddress = _baseToken;
    _baseToken_.hasUsdcPair = uniV3Oracle.isPairSupported(_baseToken, Constants.USDC);
    _baseToken_.hasWethPair = uniV3Oracle.isPairSupported(_quoteToken, Constants.WETH);

    uint256 quoteAmount = _getQuoteAmount(_baseAmount, _quoteToken_, _baseToken_);

    return quoteAmount.divWadDown(10**decimals);
  }

  function _getQuoteAmount(
    uint256 _baseAmount, 
    Token memory _quoteToken, 
    Token memory _baseToken
  ) internal view returns(uint256){
    address _quoteTokenAddress = _quoteToken.tokenAddress;
    address _baseTokenAddress = _baseToken.tokenAddress;
    uint256 quoteAmount;
    if(uniV3Oracle.isPairSupported(_quoteTokenAddress, _baseTokenAddress)){
      (quoteAmount,) = uniV3Oracle.quoteAllAvailablePoolsWithTimePeriod(
        _baseAmount.toUint128(),
        _baseTokenAddress,
        _quoteTokenAddress,
        timePeriod.toUint32()
      );
    } else {
      if(_baseToken.hasWethPair && _quoteToken.hasWethPair){
        (_baseAmount,) = uniV3Oracle.quoteAllAvailablePoolsWithTimePeriod(
          _baseAmount.toUint128(), 
          _baseTokenAddress, 
          Constants.WETH,
          timePeriod.toUint32()
        );
        _baseTokenAddress = Constants.WETH;
      } else if(_baseToken.hasUsdcPair && _quoteToken.hasUsdcPair){
        (_baseAmount,) = uniV3Oracle.quoteAllAvailablePoolsWithTimePeriod(
          _baseAmount.toUint128(), 
          _baseTokenAddress, 
          Constants.USDC,
          timePeriod.toUint32()
        );
        _baseTokenAddress = Constants.USDC;
      } else {
        return 0;
      }
      if(uniV3Oracle.isPairSupported(_quoteTokenAddress, _baseTokenAddress)){
          (quoteAmount,) = uniV3Oracle.quoteAllAvailablePoolsWithTimePeriod(
            _baseAmount.toUint128(),
            _baseTokenAddress,
            _quoteTokenAddress,
            timePeriod.toUint32()
          );
      }
    }
    return quoteAmount;
  }
}