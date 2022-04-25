//SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.6;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../interfaces/IVault.sol";
import "../libs/TransferUtils.sol";
import "../libs/FixedPointMath.sol";
import "../libs/DepositQueueLib.sol";

/**
 * @title A Vault that tokenize shares of strategy
 * @author Pods Finance
 */
contract BaseVault is IVault {
    using TransferUtils for IERC20Metadata;
    using FixedPointMath for uint256;
    using DepositQueueLib for DepositQueueLib.DepositQueue;

    IERC20Metadata public immutable underlying;

    address strategist;

    uint256 currentRoundId;
    mapping(address => uint256) userRounds;

    mapping(address => uint256) userShares;
    uint256 totalShares;

    mapping(address => uint256) withdrawRequest;
    bool withdrawWindowOpen;

    DepositQueueLib.DepositQueue private depositQueue;

    constructor(address _underlying, address _strategist) {
        underlying = IERC20Metadata(_underlying);
        strategist = _strategist;
    }

    /** Depositor **/

    /**
     * @dev See {IVault-deposit}.
     */
    function deposit(uint256 amount) public virtual override {
        underlying.safeTransferFrom(msg.sender, address(this), amount);
        depositQueue.push(DepositQueueLib.DepositEntry(msg.sender, amount));

        emit Deposit(msg.sender, amount);
    }

    /**
     * @dev Creates a request to withdraw.
     * @param owner The share owner
     */
    function requestWithdraw(address owner) external {
        withdrawRequest[owner] = currentRoundId;
        emit WithdrawRequest(owner, currentRoundId);
    }

    /**
     * @dev See {IVault-withdraw}.
     */
    function withdraw() public virtual override {
        address owner = msg.sender;

        uint256 shareAmount = sharesOf(owner);
        uint256 underlyingAmount = _burnShares(owner, shareAmount);

        // Apply custom withdraw logic
        _beforeWithdraw(shareAmount, underlyingAmount);

        underlying.transfer(owner, underlyingAmount);

        emit Withdraw(owner, shareAmount, underlyingAmount);
    }

    /**
     * @dev See {IVault-name}.
     */
    function name() external virtual override pure returns(string memory) {
        return "Base Vault";
    }

    /**
     * @dev Outputs the amount of shares and the locked shares for a given `owner` address.
     */
    function sharesOf(address owner) public virtual view returns (uint) {
        return userShares[owner];
    }

    /**
     * @dev Outputs the amount of shares that would be generated by depositing `underlyingAmount`.
     */
    function previewShares(uint256 underlyingAmount) public virtual view returns (uint256) {
        uint256 shareAmount;

        if (totalShares > 0) {
            shareAmount = underlyingAmount.mulDivUp(totalShares, _totalBalance());
        }

        return shareAmount;
    }

    /**
     * @dev Outputs the amount of underlying tokens would be withdrawn with a given amount of shares.
     */
    function previewWithdraw(uint256 shareAmount) public virtual view returns (uint256) {
        return shareAmount.mulDivDown(_totalBalance(), totalShares);
    }

    /**
     * @dev Outputs the amount of underlying tokens of an `owner` is idle, waiting for the next round.
     */
    function idleAmountOf(address owner) public virtual view returns(uint256) {
        return depositQueue.balanceOf(owner);
    }

    /** Strategist **/

    modifier onlyStrategist() {
        if (msg.sender != strategist) revert IVault__CallerIsNotTheStrategist();
        _;
    }

    /**
     * @dev Creates the next round, sending the parked funds to the
     * strategist where it should start accruing yield.
     */
    function prepareRound() public virtual onlyStrategist {
        withdrawWindowOpen = false;

        uint256 balance = underlying.balanceOf(address(this));
        underlying.safeTransfer(strategist, balance);

        emit PrepareRound(currentRoundId, balance);
    }

    /**
     * @dev Closes the round, reporting the amount yielded in the period
     * and opens the window for withdraws.
     */
    function closeRound(uint256 amountYielded) public virtual onlyStrategist {
        underlying.safeTransferFrom(msg.sender, address(this), amountYielded);
        withdrawWindowOpen = true;

        emit CloseRound(currentRoundId++, amountYielded);
    }

    function processQueuedDeposits(uint startIndex, uint endIndex) public {
        if (!withdrawWindowOpen) revert IVault__NotInWithdrawWindow();

        uint processedDeposits;
        for(uint i = startIndex; i < endIndex; i++) {
            DepositQueueLib.DepositEntry memory depositEntry = depositQueue.get(i);
            _mintShares(depositEntry.owner, depositEntry.amount, processedDeposits);
            processedDeposits += depositEntry.amount;
        }
        depositQueue.remove(startIndex, endIndex);
    }

    function depositQueueSize() external view returns(uint256) {
        return depositQueue.size();
    }

    /** Internals **/

    /**
     * @dev Calculate the total amount of assets under management.
     */
    function _totalBalance() internal virtual view returns(uint) {
        return underlying.balanceOf(strategist);
    }

    /**
     * @dev Mint new shares, effectively representing user participation in the Vault.
     */
    function _mintShares(address owner, uint256 underlyingAmount, uint256 processedDeposits) internal virtual {
        uint256 shareAmount = underlyingAmount;
        processedDeposits += _totalBalance();

        if (totalShares > 0) {
            shareAmount = underlyingAmount.mulDivUp(totalShares, processedDeposits);
        }

        userShares[owner] += shareAmount;
        totalShares += shareAmount;
    }

    /**
     * @dev Burn shares.
     * @param owner Address owner of the shares
     * @param shareAmount Amount of shares to lock
     */
    function _burnShares(address owner, uint256 shareAmount) internal virtual returns(uint claimableUnderlying) {
        if (shareAmount > userShares[owner]) revert IVault__CallerHasNotEnoughShares();
        claimableUnderlying = previewWithdraw(userShares[owner]);
        userShares[owner] -= shareAmount;
        totalShares -= shareAmount;
    }

    /** Hooks **/

    function _beforeWithdraw(uint256 shareAmount, uint256 underlyingAmount) internal virtual {}
}
