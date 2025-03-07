// SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

import "@synthetixio/core-contracts/contracts/utils/SafeCast.sol";
import "@synthetixio/core-contracts/contracts/utils/DecimalMath.sol";

import "../storage/NodeDefinition.sol";
import "../storage/NodeOutput.sol";

library PriceDeviationCircuitBreakerNode {
    using SafeCastU256 for uint256;
    using DecimalMath for int256;

    error InvalidPrice();
    error DeviationToleranceExceeded(int256 deviation);

    function process(
        NodeOutput.Data[] memory parentNodeOutputs,
        bytes memory parameters
    ) internal pure returns (NodeOutput.Data memory) {
        uint256 deviationTolerance = abi.decode(parameters, (uint256));

        int256 primaryPrice = parentNodeOutputs[0].price;
        int256 comparisonPrice = parentNodeOutputs[1].price;

        if (primaryPrice != comparisonPrice) {
            int256 difference = abs(primaryPrice - comparisonPrice).upscale(18);
            if (
                primaryPrice == 0 || deviationTolerance.toInt() < (difference / abs(primaryPrice))
            ) {
                if (parentNodeOutputs.length > 2) {
                    return parentNodeOutputs[2];
                } else {
                    revert DeviationToleranceExceeded(
                        primaryPrice == 0 ? type(int256).max : difference / primaryPrice
                    );
                }
            }
        }

        return parentNodeOutputs[0];
    }

    function abs(int256 x) private pure returns (int256) {
        return x >= 0 ? x : -x;
    }

    function validate(NodeDefinition.Data memory nodeDefinition) internal pure returns (bool) {
        // Must have 2-3 parents
        if (!(nodeDefinition.parents.length == 2 || nodeDefinition.parents.length == 3)) {
            return false;
        }

        // Must have correct length of parameters data
        if (nodeDefinition.parameters.length != 32) {
            return false;
        }

        return true;
    }
}
