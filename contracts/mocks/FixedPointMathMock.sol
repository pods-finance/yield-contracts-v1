// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.6;

import "../libs/FixedPointMath.sol";

contract FixedPointMathMock {
    using FixedPointMath for uint256;
    using FixedPointMath for FixedPointMath.Fractional;

    function mulDivUp(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) external pure returns (uint256) {
        return x.mulDivUp(y, denominator);
    }

    function mulDivDown(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) external pure returns (uint256) {
        return x.mulDivDown(y, denominator);
    }

    function mulDivUpFractional0(FixedPointMath.Fractional memory x, uint256 y) external pure returns (uint256) {
        return x.mulDivUp(y);
    }

    function mulDivDownFractional0(FixedPointMath.Fractional memory x, uint256 y) external pure returns (uint256) {
        return x.mulDivDown(y);
    }

    function mulDivUpFractional1(uint256 x, FixedPointMath.Fractional memory y) external pure returns (uint256) {
        return x.mulDivUp(y);
    }

    function mulDivDownFractional1(uint256 x, FixedPointMath.Fractional memory y) external pure returns (uint256) {
        return x.mulDivDown(y);
    }

    function fractionRoundUp(FixedPointMath.Fractional memory x) external pure returns (uint256) {
        return x.fractionRoundUp();
    }

    function fractionRoundDown(FixedPointMath.Fractional memory x) external pure returns (uint256) {
        return x.fractionRoundDown();
    }

    function min(uint256 x, uint256 y) external pure returns (uint256) {
        return FixedPointMath.min(x, y);
    }
}
