// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '../interfaces/ICurvePool.sol';
import 'lib/solmate/src/tokens/ERC20.sol';
import 'lib/solmate/src/utils/SafeTransferLib.sol';


contract SwapHelper {
    using SafeTransferLib for ERC20;

    ISwapRouter public constant swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    uint256 public immutable maxSlippageTolerance;

    constructor(uint256 _maxSlippageTolerance){
        maxSlippageTolerance = _maxSlippageTolerance;
    }

    function uniSwap(address _tokenIn, address _tokenOut) external returns(uint256){
        uint256 _amount = _amount(_tokenIn);
        _approve(_tokenIn, address(uniswapRouter), _amount);

        uint256 deadline = block.timestamp + 15; // using 'now' for convenience
        address tokenIn = _tokenIn;
        address tokenOut = _tokenOut;
        uint24 fee = 3000;
        address recipient = msg.sender;
        uint256 amountIn = _amount;
        uint256 amountOutMinimum = 0;
        uint160 sqrtPriceLimitX96 = 0;
        
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams(
            tokenIn,
            tokenOut,
            fee,
            recipient,        
            deadline,
            amountIn,
            amountOutMinimum,
            sqrtPriceLimitX96
        );
        return swapRouter.exactInputSingle(params);
    }
    
    function curveSwap(address _tokenIn) internal {
        uint256 _amount = _amount(_tokenIn);
        _approve(_tokenIn, address(curvePool), _amount);

        (uint256 i, uint256 j) = curvePool.coins(1) == tokenIn ? (1,0) : (0,1);

        curvePool.exchange(i, j, _amount, 0);
        ERC20(_tokenIn).safeTransfer(msg.sender, _amount(curvePool.coins(j)));
    }

    function _approve(address _token, address _to, uint256 _amount) internal {
        ERC20(_token).safeApprove(_to, _amount);
    }

    function _amount(address _token) internal {
        ERC20(_token).balanceOf(address(this));
    }

    function calculateMinAmountOut() internal {}

}