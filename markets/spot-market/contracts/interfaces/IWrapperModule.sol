//SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

/**
 * @title Module for synth wrappers
 */
interface IWrapperModule {
    /**
     * @notice Thrown when trader specified amounts to wrap/unwrap without holding the underlying asset.
     */
    error InsufficientFunds();

    /**
     * @notice Thrown when trader has not provided allowance for the market to transfer the underlying asset.
     */
    error InsufficientAllowance(uint expected, uint current);

    /**
     * @notice Thrown when a trade doesn't meet minimum expected return amount.
     */
    error InsufficientAmountReceived(uint expected, uint current);

    /**
     * @notice Gets fired when wrapper supply is set for a given market, collateral type.
     * @param synthMarketId Id of the market the wrapper is initialized for.
     * @param wrapCollateralType the collateral used to wrap the synth.
     * @param maxWrappableAmount the local supply cap for the wrapper.
     */
    event WrapperSet(
        uint indexed synthMarketId,
        address wrapCollateralType,
        uint256 maxWrappableAmount
    );

    /**
     * @notice Gets fired after user wraps synth
     * @param synthMarketId Id of the market.
     * @param amountWrapped amount of synth wrapped.
     * @param totalFees total fees applied on the transaction.
     * @param feesCollected fees collected by the configured FeeCollector for the market (rest of the fees are deposited to market manager).
     */
    event SynthWrapped(
        uint indexed synthMarketId,
        uint amountWrapped,
        int totalFees,
        uint feesCollected
    );

    /**
     * @notice Gets fired after user unwraps synth
     * @param synthMarketId Id of the market.
     * @param amountUnwrapped amount of synth unwrapped.
     * @param totalFees total fees applied on the transaction.
     * @param feesCollected fees collected by the configured FeeCollector for the market (rest of the fees are deposited to market manager).
     */
    event SynthUnwrapped(
        uint indexed synthMarketId,
        uint amountUnwrapped,
        int totalFees,
        uint feesCollected
    );

    /**
     * @notice Used to set the wrapper supply cap for a given market and collateral type.
     * @dev If the supply cap is set to 0 or lower than the current outstanding supply, then the wrapper is disabled.
     * @dev There is a synthetix v3 core system supply cap also set. If the current supply becomes higher than either the core system supply cap or the local market supply cap, wrapping will be disabled.
     * @param marketId Id of the market to enable wrapping for.
     * @param wrapCollateralType The collateral being used to wrap the synth.
     * @param maxWrappableAmount The maximum amount of collateral that can be wrapped.
     */
    function setWrapper(
        uint128 marketId,
        address wrapCollateralType,
        uint256 maxWrappableAmount
    ) external;

    /**
     * @notice Wraps the specified amount and returns similar value of synth minus the fees.
     * @dev Fees are collected from the user by way of the contract returning less synth than specified amount of collateral.
     * @param marketId Id of the market used for the trade.
     * @param wrapAmount Amount of collateral to wrap.  This amount gets deposited into the market collateral manager.
     * @param minAmountReceived The minimum amount of synths the trader is expected to receive, otherwise the transaction will revert.
     * @return amountReturned Amount of synth returned to user.
     */
    function wrap(
        uint128 marketId,
        uint wrapAmount,
        uint minAmountReceived
    ) external returns (uint);

    /**
     * @notice Unwraps the synth and returns similar value of collateral minus the fees.
     * @dev Transfers the specified synth, collects fees through configured fee collector, returns collateral minus fees to trader.
     * @param marketId Id of the market used for the trade.
     * @param unwrapAmount Amount of synth trader is unwrapping.
     * @param minAmountReceived The minimum amount of collateral the trader is expected to receive, otherwise the transaction will revert.
     * @return amountReturned Amount of collateral returned.
     */
    function unwrap(
        uint128 marketId,
        uint unwrapAmount,
        uint minAmountReceived
    ) external returns (uint);
}
