// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

library Events {
    /**
     * @dev Emitted when liquidity is provided to a pool.
     * @param token0 The address of the first token in the pair.
     * @param token1 The address of the second token in the pair.
     * @param amount0 The amount of token0 provided.
     * @param amount1 The amount of token1 provided.
     * @param provider The address of the liquidity provider. (indexed for efficient lookup)
     * @param timestamp The timestamp of the event.
     */
    event LiquidProvided(
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1,
        address indexed provider,
        uint timestamp
    );

    event Received(address sender, uint amount);

    /**
     * @dev Emitted when a token swap occurs.
     * @param amount The input amount of tokens.
     * @param amountOut The output amount of tokens.
     * @param from The address from which tokens were sent. (indexed for efficient lookup)
     * @param to The address to which tokens were sent. (indexed for efficient lookup)
     * @param timestamp The timestamp of the event.
     */
    event FleepSwaped(
        uint256 amount,
        uint256 amountOut,
        address indexed from,
        address indexed to,
        uint timestamp
    );

    /**
     * @dev Emitted when liquidity is removed from a pool.
     * @param token0 The address of the first token in the pair.
     * @param token1 The address of the second token in the pair.
     * @param amount0 The amount of token0 removed.
     * @param amount1 The amount of token1 removed.
     * @param provider The address of the liquidity provider. (indexed for efficient lookup)
     * @param timestamp The timestamp of the event.
     */
    event LiquidRemoved(
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1,
        address indexed provider,
        uint timestamp
    );

    /**
     * @dev Emitted when a provider's profile is updated.
     * @param provider The address of the provider whose profile was updated. (indexed for efficient lookup)
     * @param autoStake The new auto-staking preference.
     * @param timestamp The timestamp of the event.
     */
    event ProviderProfileUpdated(
        address indexed provider,
        bool autoStake,
        uint timestamp
    );

    /**
     * @dev Emitted when the swap fee is updated.
     * @param newFee The new swap fee in basis points.
     * @param updater The address that updated the fee. (indexed for efficient lookup)
     * @param timestamp The timestamp of the event.
     */
    event SwapFeeUpdated(
        uint newFee,
        address indexed updater,
        uint timestamp
    );

    /**
     * @dev Emitted when platform earnings are collected/withdrawn.
     * @param amount The amount of earnings collected.
     * @param token The address of the token collected. (indexed for efficient lookup)
     * @param timestamp The timestamp of the event.
     */
    event FeeCollected(
        uint256 amount,
        address indexed token,
        uint timestamp
    );

    /**
     * @dev Emitted when accumulated fees are burned.
     * @param amount The amount of tokens burned.
     * @param token The address of the token burned. (indexed for efficient lookup)
     * @param timestamp The timestamp of the event.
     */
    event FeeBurned(
        uint256 amount,
        address indexed token,
        uint timestamp
    );

    /**
     * @dev Emitted when a new liquidity pool is created.
     * @param poolId The unique ID of the created pool.
     * @param token0 The address of the first token in the pair.
     * @param token1 The address of the second token in the pair.
     * @param creator The address that created the pool. (indexed for efficient lookup)
     * @param timestamp The timestamp of the event.
     */
    event PoolCreated(
        uint256 indexed poolId,
        address token0,
        address token1,
        address indexed creator,
        uint timestamp
    );

    /**
     * @dev Emitted when a fiat deposit is confirmed.
     * @param user The address of the user who made the deposit. (indexed)
     * @param ngnAmount The NGN amount of the fiat deposit.
     * @param afxAmount The AFX amount minted from the deposit.
     * @param transactionRef The reference ID for the fiat transaction.
     */
    event FiatDepositConfirmed(
        address indexed user,
        uint256 ngnAmount,
        uint256 afxAmount,
        string transactionRef
    );

    /**
     * @dev Emitted when AFX tokens are minted.
     * @param to The address to which tokens were minted. (indexed)
     * @param amount The amount of AFX tokens minted.
     * @param ngnValue The NGN value of the minted tokens.
     * @param fee The fee incurred during minting.
     */
    event TokensMinted(
        address indexed to,
        uint256 amount,
        uint256 ngnValue,
        uint256 fee
    );

    /**
     * @dev Emitted when AFX tokens are burned.
     * @param from The address from which tokens were burned. (indexed)
     * @param amount The amount of AFX tokens burned.
     * @param ngnValue The NGN value of the burned tokens.
     * @param fee The fee incurred during burning.
     */
    event TokensBurned(
        address indexed from,
        uint256 amount,
        uint256 ngnValue,
        uint256 fee
    );

    /**
     * @dev Emitted when collateral is deposited.
     * @param user The address of the user who deposited collateral. (indexed)
     * @param collateral The address of the collateral token. (indexed)
     * @param amount The amount of collateral deposited.
     */
    event CollateralDeposited(
        address indexed user,
        address indexed collateral,
        uint256 amount
    );

    /**
     * @dev Emitted when collateral is withdrawn.
     * @param user The address of the user who withdrew collateral. (indexed)
     * @param collateral The address of the collateral token. (indexed)
     * @param amount The amount of collateral withdrawn.
     */
    event CollateralWithdrawn(
        address indexed user,
        address indexed collateral,
        uint256 amount
    );

    /**
     * @dev Emitted when AFX tokens are minted against crypto collateral.
     * @param user The address of the user who minted tokens. (indexed)
     * @param collateral The address of the collateral token. (indexed)
     * @param collateralAmount The amount of collateral used.
     * @param mintedAmount The amount of AFX tokens minted.
     */
    event CryptoMint(
        address indexed user,
        address indexed collateral,
        uint256 collateralAmount,
        uint256 mintedAmount
    );

    /**
     * @dev Emitted when AFX tokens are burned and crypto collateral is released.
     * @param user The address of the user. (indexed)
     * @param collateral The address of the collateral token. (indexed)
     * @param burnedAmount The amount of AFX tokens burned.
     * @param collateralReleased The amount of collateral released.
     */
    event CryptoBurn(
        address indexed user,
        address indexed collateral,
        uint256 burnedAmount,
        uint256 collateralReleased
    );

    /**
     * @dev Emitted when a user's position is liquidated.
     * @param user The address of the user whose position was liquidated. (indexed)
     * @param collateral The address of the collateral token. (indexed)
     * @param collateralLiquidated The amount of collateral liquidated.
     * @param debtCovered The amount of debt covered by the liquidation.
     */
    event Liquidation(
        address indexed user,
        address indexed collateral,
        uint256 collateralLiquidated,
        uint256 debtCovered
    );

    /**
     * @dev Emitted when collateral asset parameters are updated.
     * @param collateral The address of the collateral token. (indexed)
     * @param newCollateralRatio The new required over-collateralization ratio.
     * @param newLiquidationThreshold The new liquidation threshold.
     * @param newDebtCeiling The new debt ceiling for the collateral.
     */
    event CollateralAssetUpdated(
        address indexed collateral,
        uint256 newCollateralRatio,
        uint256 newLiquidationThreshold,
        uint256 newDebtCeiling
    );

    /**
     * @dev Emitted when the system's fiat reserves are updated.
     * @param oldReserves The fiat reserves before the update.
     * @param newReserves The fiat reserves after the update.
     */
    event FiatReservesUpdated(uint256 oldReserves, uint256 newReserves);

    /**
     * @dev Emitted when rebalancing is triggered.
     * @param currentFiatRatio The current fiat backing ratio.
     * @param targetFiatRatio The target fiat backing ratio.
     */
    event RebalanceTriggered(uint256 currentFiatRatio, uint256 targetFiatRatio);

    /**
     * @dev Emitted when the NGN exchange rate is updated.
     * @param oldRate The exchange rate before the update.
     * @param newRate The exchange rate after the update.
     */
    event ExchangeRateUpdated(uint256 oldRate, uint256 newRate);

    /**
     * @dev Emitted when the minter status of an account is updated.
     * @param account The address of the account. (indexed)
     * @param status True if the account is now a minter, false otherwise.
     */
    event MinterStatusUpdated(address indexed account, bool status);

    /**
     * @dev Emitted when the burner status of an account is updated.
     * @param account The address of the account. (indexed)
     * @param status True if the account is now a burner, false otherwise.
     */
    event BurnerStatusUpdated(address indexed account, bool status);

    /**
     * @dev Emitted when the oracle status of an account is updated.
     * @param account The address of the account. (indexed)
     * @param status True if the account is now an oracle, false otherwise.
     */
    event OracleStatusUpdated(address indexed account, bool status);

    /**
     * @dev Emitted when the liquidator status of an account is updated.
     * @param account The address of the account. (indexed)
     * @param status True if the account is now a liquidator, false otherwise.
     */
    event LiquidatorStatusUpdated(address indexed account, bool status);

    /**
     * @dev Emitted when the blacklist status of an account is updated.
     * @param account The address of the account. (indexed)
     * @param status True if the account is now blacklisted, false otherwise.
     */
    event BlacklistStatusUpdated(address indexed account, bool status);

    /**
     * @dev Emitted when the stability fee rate is updated.
     * @param oldRate The stability fee rate before the update.
     * @param newRate The stability fee rate after the update.
     */
    event StabilityFeeRateUpdated(uint256 oldRate, uint256 newRate);

    /**
     * @dev Emitted when the target fiat ratio is updated.
     * @param oldRatio The target fiat ratio before the update.
     * @param newRatio The target fiat ratio after the update.
     */
    event TargetFiatRatioUpdated(uint256 oldRatio, uint256 newRatio);

    /**
     * @dev Emitted when the fiat ratio limits are updated.
     * @param oldMinRatio The minimum fiat ratio before the update.
     * @param oldMaxRatio The maximum fiat ratio before the update.
     * @param newMinRatio The minimum fiat ratio after the update.
     * @param newMaxRatio The maximum fiat ratio after the update.
     */
    event FiatRatioLimitsUpdated(
        uint256 oldMinRatio,
        uint256 oldMaxRatio,
        uint256 newMinRatio,
        uint256 newMaxRatio
    );

    /**
     * @dev Emitted when a new collateral asset is added.
     * @param tokenAddress The address of the new collateral token. (indexed)
     * @param collateralRatio The default collateral ratio set for this asset.
     * @param debtCeiling The default debt ceiling set for this asset.
     */
    event CollateralAssetAdded(
        address indexed tokenAddress,
        uint256 collateralRatio,
        uint256 debtCeiling
    );
}