//SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.6;

import "../interfaces/IVault.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract StrategyHelper {
    // Functions related to the USER

    /**
     * @dev Get Idle Balance of a certain user, meaning the balance waiting to
     * start the next round to be converted in shares.
     * @param strategy strategy address
     * @param user account address
     * @return idleBalance uint256 user's idle balance
     */
    function getUserIdleBalance(address strategy, address user)
        public
        view
        returns (uint256 idleBalance)
    {
        // return IVault(strategy).idleBalance(user);
    }

    /**
     * @dev Get Invested Balance of a certain user,
     * It checks the yield source balance (Curve, Lido, AAVE).
     * @param strategy strategy address
     * @param user account address
     * @return investedBalance uint256 user's invested balance
     */
    function getUserInvestedBalance(address strategy, address user)
        public
        view
        returns (uint256 investedBalance)
    {
        uint256 sharePrice = getSharePrice(strategy);
        uint256 userShares = getUserShares(strategy, user);
        uint8 shareDecimals = getSharesDecimals(strategy);
        return (userShares * sharePrice) / 10**shareDecimals;
    }

    /**
     * @dev Get Total Balance of a certain user, Sum of Idle and Invested
     * @param strategy strategy address
     * @param user account address
     * @return totalBalance uint256 user's total balance
     */
    function getUserTotalBalance(address strategy, address user)
        public
        view
        returns (uint256 totalBalance)
    {
        return
            getUserIdleBalance(strategy, user) +
            getUserInvestedBalance(strategy, user);
    }

    /**
     * @dev Get shares of a certain user
     * @param strategy strategy address
     * @param user account address
     * @return shares uint256 user's shares
     */
    function getUserShares(address strategy, address user)
        public
        view
        returns (uint256 shares)
    {
        // return IVault(strategy).balanceOf(user);
    }

    // Functions related to the system

    /**
     * @param strategy strategy address
     * @return sharePrice
     */
    function getSharePrice(address strategy)
        public
        view
        returns (uint256 sharePrice)
    {
        // return IVault(strategy).sharePrice(strategy);
    }

    /**
     * @param strategy strategy address
     * @return shareDecimals
     */
    function getSharesDecimals(address strategy)
        public
        view
        returns (uint8 shareDecimals)
    {
        // return IVault(strategy).decimals(strategy);
    }

    /**
     * @param strategy strategy address
     * @return strategyTVL return the strategy total TVL (idle + invested)
     */
    function getStrategyTVL(address strategy)
        public
        view
        returns (uint256 strategyTVL)
    {
        // address strategyTokenBase = IVault(strategy).underlying(strategy);
        // uint256 idleBalance = IERC20(strategyTokenBase).balanceOf(strategy);
        // uint256 investedBalance = IVault(strategy).totalBalance();
        // return idleBalance + investedBalance;
    }

    /**
     * @dev Check if the strategy vault is currently in the round preparation phase
     * @param strategy strategy address
     * @return isRoundPreparation
     */
    function isCurrentRoundPreparation(address strategy)
        public
        view
        returns (bool isRoundPreparation)
    {
        // return IVault(strategy).isRoundPreparation(strategy);
    }
}
