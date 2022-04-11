//SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.6;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../interfaces/IVault.sol";
import "../libs/TransferUtils.sol";
import "../libs/FixedPointMath.sol";

contract BaseVault is IVault {
    using TransferUtils for IERC20Metadata;
    using FixedPointMath for uint256;

    IERC20Metadata public immutable underlying;

    address strategist;

    uint256 currentRoundId;
    mapping(address => uint256) userRounds;

    mapping(address => uint256) userShares;
    uint256 totalShares;

    mapping(address => uint256) userLockedShares;
    uint256 totalLockedShares;

    mapping(address => uint256) withdrawRequest;
    bool withdrawWindowOpen;

    constructor(address _underlying, address _strategist) {
        underlying = IERC20Metadata(_underlying);
        strategist = _strategist;
    }

    /** Depositor **/

    /**
     * @dev See {IVault-deposit}.
     */
    function deposit(uint256 amount) public virtual override {
        uint256 shareAmount = previewShares(amount);

        underlying.safeTransferFrom(msg.sender, address(this), amount);

        _unlockPreviousShares(msg.sender);
        _mintLockedShares(msg.sender, shareAmount);

        emit Deposit(msg.sender, shareAmount, amount);
    }

    function requestWithdraw(address owner) external {
        withdrawRequest[owner] = currentRoundId;
        emit WithdrawRequest(owner, currentRoundId);
    }

    /**
     * @dev See {IVault-withdraw}.
     */
    function withdraw() public virtual override {
        address owner = msg.sender;
        if (!withdrawWindowOpen) revert IVault__NotInWithdrawWindow();
        if (withdrawRequest[owner] != currentRoundId - 1) revert IVault__WithdrawNotAllowed();

        _unlockPreviousShares(owner);

        (uint256 shareAmount,) = sharesOf(owner);
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
    function sharesOf(address owner) public virtual view returns (uint256 unlocked, uint256 locked) {
        locked = userLockedShares[owner];

        if (userRounds[owner] < currentRoundId) {
            locked = 0;
        }

        unlocked = userShares[owner] - locked;
    }

    /**
     * @dev Outputs the amount of shares that would be generated by depositing `underlyingAmount`.
     */
    function previewShares(uint256 underlyingAmount) public virtual view returns (uint256) {
        uint256 shareAmount = underlyingAmount;

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

    /** Strategist **/

    modifier onlyStrategist() {
        if (msg.sender != strategist) revert IVault__CallerIsNotTheStrategist();
        _;
    }

    function prepareRound() public virtual onlyStrategist {
        withdrawWindowOpen = false;

        uint256 balance = underlying.balanceOf(address(this));
        underlying.safeTransfer(strategist, balance);

        emit PrepareRound(currentRoundId, balance);
    }

    function closeRound(uint256 amountYielded) public virtual onlyStrategist {
        underlying.safeTransferFrom(msg.sender, address(this), amountYielded);
        withdrawWindowOpen = true;

        emit CloseRound(currentRoundId++, amountYielded);
    }

    /** Internals **/

    /**
     * @dev Calculate the total amount of assets under management.
     */
    function _totalBalance() internal virtual view returns(uint) {
        return underlying.balanceOf(strategist) + underlying.balanceOf(address(this));
    }

    /**
     * @dev Mint new shares, and locks them until they the next round.
     * @param owner Address owner of the shares
     * @param shareAmount Amount of shares to lock
     */
    function _mintLockedShares(address owner, uint256 shareAmount) internal virtual {
        userShares[owner] += shareAmount;
        totalShares += shareAmount;

        userLockedShares[owner] += shareAmount;
        totalLockedShares += shareAmount;
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

    /**
     * @dev If owner has previous locked shares, unlocks them.
     * @param owner Address owner of the shares
     */
    function _unlockPreviousShares(address owner) internal virtual {
        if (userRounds[owner] < currentRoundId) {
            totalLockedShares -= userLockedShares[owner];
            userLockedShares[owner] = 0;
            userRounds[owner] = currentRoundId;
        }
    }

    /** Hooks **/

    function _beforeWithdraw(uint256 shareAmount, uint256 underlyingAmount) internal virtual {}
}
