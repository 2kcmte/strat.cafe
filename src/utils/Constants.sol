// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

library Constants {
    ///@dev uniswap V3 router 
    ISwapRouter public constant SWAP_ROUTER_V3 = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    ///@dev uniswap v2 router
    IUniswapV2Router02 public constant SWAP_ROUTER_V2 = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    ///@dev sushiswap router
    IUniswapV2Router02 public constant SWAP_ROUTER_SUSHI = IUniswapV2Router02(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);

    ///@dev USDC contract address
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    ///@dev WETH contract addresss
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    uint256 public constant MAX_VALUE = type(uint256).max;

    address public constant ADDRESS_ZERO = address(0);

    uint256 public constant ZERO = 0;

    uint256 public constant ONE = 1;

    uint256 public constant TWO = 2;
    
    ///@dev harvest interval set to 2.5 days
    uint256 public constant HARVEST_INTERVAL = 216000 seconds;

    uint256 public constant BASE = 1e5; // 10_00_00
}