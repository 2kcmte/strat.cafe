// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

interface IAlchemistV2 {

    event PendingAdminUpdated(address value);

    event AdminUpdated(address sentinel, bool flag);

    event SentinelSet(address keeper, bool flag);

    event KeeperSet(address value);

    event AddUnderlyingToken(address indexed token);

    event AddYieldToken(address indexed token, address adapter);

    event UnderlyingTokenEnabled(address indexed underlyingToken);

    event UnderlyingTokenDisabled(address indexed underlyingToken);

    event YieldTokenEnabled(address indexed yieldToken);

    event YieldTokenDisabled(address indexed yieldToken);

    event RepayLimitUpdated(

        address indexed underlyingToken,

        uint256 maximum,

        uint256 blocks

    );

    event LiquidationLimitUpdated(

        address indexed underlyingToken,

        uint256 maximum,

        uint256 blocks

    );

    event TransmuterUpdated(address value);

    event MinimumCollateralizationUpdated(uint256 value);

    event ProtocolFeeUpdated(uint256 value);

    event ProtocolFeeReceiverUpdated(address value);

    event MintingLimitUpdated(uint256 maximum, uint256 blocks);

    event MaximumLossUpdated(address indexed yieldToken, uint256 value);

    event Snap(address indexed yieldToken, uint256 expectedValue);

    event ApproveMint(

        address indexed owner,

        address indexed spender,

        uint256 amount

    );

    event ApproveWithdraw(

        address indexed owner,

        address indexed spender,

        uint256 amount

    );

    event Harvest(address indexed yieldToken, uint256 minimumAmountOut, uint256 totalHarvested);

    event Deposit(

        address indexed sender,

        address indexed yieldToken,

        uint256 amount,

        address recipient

    );

    event Withdraw(

        address indexed sender,

        address indexed yieldToken,

        uint256 shares,

        address recipient

    );

    event Mint(address indexed owner, uint256 amount, address recipient);

    event Burn(address indexed sender, uint256 amount, address recipient);

    event Repay(

        address indexed sender,

        address indexed underlyingToken,

        uint256 amount,

        address recipient

    );

    event Liquidate(

        address indexed sender,

        address indexed yieldToken,

        uint256 shares

    );

    event Donate(

        address indexed sender,

        address indexed yieldToken,

        uint256 amount

    );

    error SlippageExceeded();

    error ExpectedValueExceeded(

        address yieldToken,

        uint256 expectedValue,

        uint256 maximumExpectedValue

    );

    error LossExceeded(address yieldToken, uint256 loss, uint256 maximumLoss);

    error MintingLimitExceeded(uint256 amount, uint256 mintingLimit);

    error RepayLimitExceeded(

        address underlyingToken,

        uint256 amount,

        uint256 repayLimit

    );

    error LiquidationLimitExceeded(

        address underlyingToken,

        uint256 amount,

        uint256 repayLimit

    );

    error Undercollateralized();

    error UnsupportedToken(address token);

    error IllegalState(string message);

    error IllegalArgument(string message);

    error Unauthorized(string message);

    error TokenDisabled(address token);

    function approveMint(address spender, uint256 amount) external;

    function approveWithdraw(address spender, uint256 amount) external;

    function poke(address owner) external;

    function deposit(

        address yieldToken,

        uint256 amount,

        address recipient

    ) external;

    function depositUnderlying(

        address yieldToken,

        uint256 amount,

        address recipient,

        uint256 minimumAmountOut

    ) external;

    function withdraw(

        address yieldToken,

        uint256 shares,

        address recipient

    ) external;

    function withdrawFrom(

        address owner,

        address token,

        uint256 shares,

        address recipient

    ) external;

    function withdrawUnderlying(

        address yieldToken,

        uint256 shares,

        address recipient,

        uint256 minimumAmountOut

    ) external;

    function withdrawUnderlyingFrom(

        address owner,

        address token,

        uint256 shares,

        address recipient,

        uint256 minimumAmountOut

    ) external;

    function mint(uint256 amount, address recipient) external;

    function mintFrom(

        address owner,

        uint256 amount,

        address recipient

    ) external;

    function burn(uint256 amount, address recipient) external;

    function repay(

        address underlyingToken,

        uint256 amount,

        address recipient

    ) external;

    function liquidate(

        address yieldToken,

        uint256 amountUnderlying,

        uint256 minimumAmountOut

    ) external;

    function donate(address yieldToken, uint256 amount) external;

    function harvest(address yieldToken, uint256 minimumAmountOut) external;

    function debtToken() external view returns (address);

    function admin() external view returns (address);

    function pendingAdmin() external view returns (address);

    function sentinels(address value) external view returns (bool);

    function keepers(address value) external view returns (bool);

    function transmuter() external view returns (address);

    function minimumCollateralization() external view returns (uint256);

    function protocolFee() external view returns (uint256);

    function protocolFeeReceiver() external view returns (address);

    function getUnderlyingTokensPerShare(address yieldToken)

        external

        view

        returns (uint256);

    function getYieldTokensPerShare(address yieldToken)

        external

        view

        returns (uint256);

    function getSupportedUnderlyingTokens()

        external

        view

        returns (address[] memory);

    function getSupportedYieldTokens() external view returns (address[] memory);

    function isSupportedUnderlyingToken(address underlyingToken)

        external

        view

        returns (bool);

    function isSupportedYieldToken(address yieldToken)

        external

        view

        returns (bool);

    function accounts(address owner)

        external

        view

        returns (int256 debt, address[] memory depositedTokens);

    function positions(address owner, address yieldToken)

        external

        view

        returns (uint256 balance, uint256 lastAccruedWeight);

    function getUnderlyingTokenParameters(address underlyingToken)

        external

        view

        returns (

            uint8 decimals,

            uint256 scalingFactor,

            bool enabled

        );

    function getYieldTokenParameters(address yieldToken)

        external

        view

        returns (

            uint8 decimals,

            address underlyingToken,

            address adapter,

            uint256 maximumLoss,

            uint256 balance,

            uint256 totalShares,

            uint256 expectedValue,

            uint256 accruedWeight,

            bool enabled

        );

    function mintAllowance(address owner, address spender)

        external

        view

        returns (uint256);

    function withdrawAllowance(address owner, address spender)

        external

        view

        returns (uint256);

    function convertYieldTokensToShares(address yieldToken, uint256 amount) external view returns (uint256);

    function convertSharesToYieldTokens(address yieldToken, uint256 shares) external view returns (uint256);

    function convertSharesToUnderlyingTokens(address yieldToken, uint256 shares) external view returns (uint256);

    function convertYieldTokensToUnderlying(address yieldToken, uint256 amount) external view returns (uint256);

    function convertUnderlyingTokensToYield(address yieldToken, uint256 amount) external view returns (uint256);

    function convertUnderlyingTokensToShares(address yieldToken, uint256 amount) external view returns (uint256);

    function normalizeUnderlyingTokensToDebt(address underlyingToken, uint256 amount) external view returns (uint256);

    function normalizeDebtTokensToUnderlying(address underlyingToken, uint256 amount) external view returns (uint256);

    function totalValue(address owner) external view returns (uint256);

}
