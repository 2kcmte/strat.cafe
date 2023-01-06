// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IPool {
    /**
     * @notice Enable or disable buyback
     * @param state whether to enable or disable buyback
     * @param isCallPool true to set state for call pool, false for put pool
     */
    function setBuybackEnabled(bool state, bool isCallPool) external;
    
    /**
     * @notice deposit underlying currency, underwriting calls of that currency with respect to base currency
     * @param amount quantity of underlying currency to deposit
     * @param isCallPool whether to deposit underlying in the call pool or base in the put pool
     */
    function deposit(uint256 amount, bool isCallPool) external payable;

    /**
     * @notice redeem pool share tokens for underlying asset
     * @param amount quantity of share tokens to redeem
     * @param isCallPool whether to deposit underlying in the call pool or base in the put pool
     */
    function withdraw(uint256 amount, bool isCallPool) external;
    
    /**
     * @notice claim earned PREMIA emissions
     * @param isCallPool true for call, false for put
     */
    function claimRewards(bool isCallPool) external;

    /**
     * @notice claim earned PREMIA emissions on behalf of given account
     * @param account account on whose behalf to claim rewards
     * @param isCallPool true for call, false for put
     */
    function claimRewards(address account, bool isCallPool) external;

    
    /**
     * @notice get TVL (total value locked) for given address
     * @param account address whose TVL to query
     * @return underlyingTVL user total value locked in call pool (in underlying token amount)
     * @return baseTVL user total value locked in put pool (in base token amount)
     */
    function getUserTVL(address account)
        external
        view
        returns (uint256 underlyingTVL, uint256 baseTVL);



}
