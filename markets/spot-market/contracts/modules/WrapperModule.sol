//SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

import "@synthetixio/core-contracts/contracts/utils/DecimalMath.sol";
import "@synthetixio/core-contracts/contracts/interfaces/IERC20.sol";
import "@synthetixio/main/contracts/interfaces/IMarketCollateralModule.sol";
import "@synthetixio/core-contracts/contracts/utils/SafeCast.sol";
import "../storage/SpotMarketFactory.sol";
import "../interfaces/IWrapperModule.sol";
import "../storage/Wrapper.sol";
import "../storage/Price.sol";
import "../storage/FeeConfiguration.sol";
import "../utils/SynthUtil.sol";

/**
 * @title Module for wrapping and unwrapping collateral for synths.
 * @dev See IWrapperModule.
 */
contract WrapperModule is IWrapperModule {
    using DecimalMath for uint256;
    using SpotMarketFactory for SpotMarketFactory.Data;
    using Price for Price.Data;
    using Wrapper for Wrapper.Data;
    using SafeCastU256 for uint256;
    using SafeCastI256 for int256;

    /**
     * @inheritdoc IWrapperModule
     */
    function setWrapper(
        uint128 marketId,
        address wrapCollateralType,
        uint256 maxWrappableAmount
    ) external override {
        SpotMarketFactory.load().onlyMarketOwner(marketId);

        Wrapper.update(marketId, wrapCollateralType, maxWrappableAmount);

        emit WrapperSet(marketId, wrapCollateralType, maxWrappableAmount);
    }

    /**
     * @inheritdoc IWrapperModule
     */
    function wrap(
        uint128 marketId,
        uint256 wrapAmount,
        uint minAmountReceived
    ) external override returns (uint256 amountToMint) {
        SpotMarketFactory.Data storage spotMarketFactory = SpotMarketFactory.load();
        Wrapper.Data storage wrapperStore = Wrapper.load(marketId);
        spotMarketFactory.isValidMarket(marketId);
        wrapperStore.isValidWrapper();

        // revert when wrapping more than the supply cap
        wrapperStore.checkMaxWrappableAmount(
            marketId,
            wrapAmount,
            IMarketCollateralModule(spotMarketFactory.synthetix)
        );

        IERC20 wrappingCollateral = IERC20(wrapperStore.wrapCollateralType);
        wrappingCollateral.transferFrom(msg.sender, address(this), wrapAmount);
        wrappingCollateral.approve(spotMarketFactory.synthetix, wrapAmount);
        IMarketCollateralModule(spotMarketFactory.synthetix).depositMarketCollateral(
            marketId,
            wrapperStore.wrapCollateralType,
            wrapAmount
        );

        uint256 wrapAmountInUsd = Price.synthUsdExchangeRate(
            marketId,
            wrapAmount,
            Transaction.Type.WRAP
        );

        (uint256 returnAmountUsd, int256 totalFees, ) = FeeConfiguration.calculateFees(
            marketId,
            msg.sender,
            wrapAmountInUsd,
            Price.getCurrentPrice(marketId, Transaction.Type.WRAP),
            Transaction.Type.WRAP
        );

        amountToMint = Price.usdSynthExchangeRate(marketId, returnAmountUsd, Transaction.Type.WRAP);

        if (amountToMint < minAmountReceived) {
            revert InsufficientAmountReceived(minAmountReceived, amountToMint);
        }

        uint collectedFees;
        if (totalFees > 0) {
            IMarketManagerModule(spotMarketFactory.synthetix).withdrawMarketUsd(
                marketId,
                address(this),
                totalFees.toUint()
            );
            collectedFees = FeeConfiguration.collectFees(
                marketId,
                totalFees,
                msg.sender,
                Transaction.Type.WRAP,
                address(0)
            );
        }

        SynthUtil.getToken(marketId).mint(msg.sender, amountToMint);

        emit SynthWrapped(marketId, amountToMint, totalFees, collectedFees);
    }

    /**
     * @inheritdoc IWrapperModule
     */
    function unwrap(
        uint128 marketId,
        uint256 unwrapAmount,
        uint minAmountReceived
    ) external override returns (uint256 returnCollateralAmount) {
        SpotMarketFactory.Data storage spotMarketFactory = SpotMarketFactory.load();
        Wrapper.Data storage wrapperStore = Wrapper.load(marketId);
        spotMarketFactory.isValidMarket(marketId);
        wrapperStore.isValidWrapper();

        ITokenModule synth = SynthUtil.getToken(marketId);

        // transfer from seller
        synth.transferFrom(msg.sender, address(this), unwrapAmount);

        // TODO: do i need to transfer to burn?
        synth.burn(address(this), unwrapAmount);

        uint256 unwrapAmountInUsd = Price.synthUsdExchangeRate(
            marketId,
            unwrapAmount,
            Transaction.Type.UNWRAP
        );
        (uint256 returnAmountUsd, int256 totalFees, ) = FeeConfiguration.calculateFees(
            marketId,
            msg.sender,
            unwrapAmountInUsd,
            Price.getCurrentPrice(marketId, Transaction.Type.UNWRAP),
            Transaction.Type.UNWRAP
        );

        returnCollateralAmount = Price.usdSynthExchangeRate(
            marketId,
            returnAmountUsd,
            Transaction.Type.UNWRAP
        );

        if (returnCollateralAmount < minAmountReceived) {
            revert InsufficientAmountReceived(minAmountReceived, returnCollateralAmount);
        }
        uint collectedFees;
        if (totalFees > 0) {
            IMarketManagerModule(spotMarketFactory.synthetix).withdrawMarketUsd(
                marketId,
                address(this),
                totalFees.toUint()
            );
            collectedFees = FeeConfiguration.collectFees(
                marketId,
                totalFees,
                msg.sender,
                Transaction.Type.UNWRAP,
                address(0)
            );
        }

        IMarketCollateralModule(spotMarketFactory.synthetix).withdrawMarketCollateral(
            marketId,
            wrapperStore.wrapCollateralType,
            returnCollateralAmount
        );

        ITokenModule(wrapperStore.wrapCollateralType).transfer(msg.sender, returnCollateralAmount);

        emit SynthUnwrapped(marketId, returnCollateralAmount, totalFees, collectedFees);
    }
}
