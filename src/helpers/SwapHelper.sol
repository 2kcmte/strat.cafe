// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "solmate/tokens/ERC20.sol";
import "solmate/utils/SafeTransferLib.sol";
import "solmate/utils/FixedPointMathLib.sol";
import "./OracleWrapper.sol";
import "../interfaces/curve/ICurvePool.sol";
import "../utils/Errors.sol";
import "../utils/Constants.sol";

contract SwapHelper {
    using SafeTransferLib for ERC20;
    using SafeCast for uint256;
    using SafeCast for int256;
    using FixedPointMathLib for uint256;

    OracleWrapper public immutable oracle;
    uint256 public immutable slippageTolerance;

    constructor(address _oracle, uint256 _slippageTolerance){
        oracle = OracleWrapper(_oracle);
        slippageTolerance = _slippageTolerance;
    }

    function uniSwapV3(address _tokenIn, address _tokenOut) external returns(uint256){
        // amount to swap
        uint256 _amount = _totalBalance(_tokenIn);
        // approve token to uniswap router
        _approve(_tokenIn, address(Constants.SWAP_ROUTER_V3), _amount);

        uint256 deadline = block.timestamp + 15; // using 'now' for convenience
        uint24 fee = 3000;
        uint256 amountOutVirtual = oracle.getQuoteAmount(_tokenOut, _tokenIn, _amount);
        uint256 amountOutMinimum = amountOutVirtual - (amountOutVirtual * slippageTolerance/Constants.BASE);
        uint160 sqrtPriceLimitX96;
        
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams(
            _tokenIn,
            _tokenOut,
            fee,
            msg.sender,        
            deadline,
            _amount,
            amountOutMinimum,
            sqrtPriceLimitX96
        );
        return Constants.SWAP_ROUTER_V3.exactInputSingle(params);
    }

    function sushiSwap(
        address _tokenIn, 
        address[] memory path,
        uint256 minAmtOut
    ) public {
       Constants.SWAP_ROUTER_SUSHI.swapExactTokensForTokens(
        _totalBalance(_tokenIn),
        minAmtOut,
        path,
        msg.sender,
        block.timestamp + 15 minutes
       );
    }

    function swapTokenMultiHopWeth(address _tokenIn, address _tokenOut) external returns(uint256){
        address[] memory path;
        path[0] = _tokenIn;
        if(_tokenIn != Constants.WETH && _tokenOut != Constants.WETH){
            path[1] = Constants.WETH;
            path[2] = _tokenOut;
        } else {
            path[1] = _tokenOut;
        }
        sushiSwap(_tokenIn, path, Constants.ZERO);
        return _totalBalance(_tokenOut);
    }
    
    function curveSwap(address _tokenIn, ICurvePool curvePool) external returns(uint256){
        uint256 _amount = _totalBalance(_tokenIn);
        // approve to curve pool
        _approve(_tokenIn, address(curvePool), _amount);
        (uint256 i, uint256 j) = curvePool.coins(Constants.ONE) == _tokenIn 
            ? (Constants.ONE, Constants.ZERO) : (Constants.ZERO, Constants.ONE);

        curvePool.exchange(
            i.toInt256().toInt128(), 
            j.toInt256().toInt128(), 
            _amount, 
            _amount - (_amount * slippageTolerance/Constants.BASE)
        );
        uint256 amtOut = _totalBalance(curvePool.coins(j));
        ERC20(_tokenIn).safeTransfer(msg.sender, amtOut);
        return amtOut;
    }

    function _approve(address _token, address _to, uint256 _amount) internal {
        ERC20(_token).safeApprove(_to, _amount);
    }

    function _totalBalance(address _token) internal view returns(uint256){
        return ERC20(_token).balanceOf(address(this));
    }

}