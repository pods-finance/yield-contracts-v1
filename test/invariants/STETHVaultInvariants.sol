// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.6;

import "../../contracts/mocks/Asset.sol";
import "../../contracts/vaults/STETHVault.sol";
import "../../contracts/configuration/ConfigurationManager.sol";
import "../../contracts/mocks/InvestorActorMock.sol";
import "../../contracts/mocks/YieldSourceMock.sol";

contract STETH is Asset {
    constructor() Asset("Liquid staked Ether 2.0", "stETH") {}

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        _mint(from, amount);
        _transfer(from, to, amount);
        return true;
    }

    function generateInterest(uint256 interest) public {
        _mint(msg.sender, interest);
    }
}

library String {
    function equal(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}

contract STETHVaultInvariants is STETHVault {
    ConfigurationManager public $configuration = new ConfigurationManager();
    STETH public $asset = new STETH();
    InvestorActorMock public $investor = new InvestorActorMock(address($asset));
    event AssertionFailed(bool);

    struct LastDeposit {
        uint256 amount;
        uint256 roundId;
        uint256 shares;
    }

    mapping(address => LastDeposit) public lastDeposits;

    constructor() STETHVault($configuration, $asset, address($investor)) {
        $configuration.setParameter(address(this), "VAULT_CONTROLLER", 0x30000);
    }

    function echidna_test_name() public view returns (bool) {
        return String.equal(name(), "Pods Yield stETH");
    }

    function echidna_test_symbol() public returns (bool) {
        return String.equal(symbol(), "pystETH");
    }

    function echidna_test_decimals() public returns (bool) {
        return decimals() == $asset.decimals();
    }

    function generateInterest(uint256 a) public {
        if (a == 0) return;
        uint256 addInterest = (totalAssets() / a);
        $asset.generateInterest(addInterest);
    }

    //  ["0x10000", "0x20000", "0x30000"]
    function echidna_sum_total_supply() public returns (bool) {
        uint256 balanceA = balanceOf(address(0x10000));
        uint256 balanceB = balanceOf(address(0x20000));
        uint256 balanceC = balanceOf(address(0x30000));

        uint256 sumBalances = balanceA + balanceB + balanceC;

        return sumBalances == totalSupply();
    }

    function helpDeploy(uint256 a) public {
        if (a > depositQueueSize()) return;
        uint256 startIndex = 0;
        uint256 endIndex = a;
        processQueuedDeposits(startIndex, endIndex);
    }

    function deposit(uint256 assets, address) public override returns (uint256 shares) {
        uint256 createdShares = convertToShares(assets);
        LastDeposit memory newDeposit = LastDeposit({ amount: assets, roundId: currentRoundId, shares: createdShares });
        lastDeposits[msg.sender] = newDeposit;
        super.deposit(assets, msg.sender);
    }

    function mint(uint256 shares, address) public override returns (uint256 assets) {
        uint256 assets2 = convertToAssets(shares);
        LastDeposit memory newDeposit = LastDeposit({ amount: assets2, roundId: currentRoundId, shares: shares });
        lastDeposits[msg.sender] = newDeposit;
        super.mint(shares, msg.sender);
    }

    function withdraw(
        uint256 assets,
        address,
        address
    ) public override returns (uint256 shares) {
        bool isNextRound = currentRoundId == lastDeposits[msg.sender].roundId + 1;
        super.withdraw(assets, msg.sender, msg.sender);

        if (isNextRound && assets > 0) {
            uint256 burnShares = previewWithdraw(assets);
            if (burnShares <= lastDeposits[msg.sender].shares) {
                bool condition = assets <= lastDeposits[msg.sender].amount;
                if (!condition) {
                    emit AssertionFailed(condition);
                }
            }
        }
    }

    function redeem(
        uint256 shares,
        address,
        address
    ) public override returns (uint256 assets) {
        bool isNextRound = currentRoundId == lastDeposits[msg.sender].roundId + 1;
        super.redeem(shares, msg.sender, msg.sender);
        if (isNextRound && shares > 0) {
            if (shares <= lastDeposits[msg.sender].shares) {
                uint256 withdrawAssets = convertToAssets(shares);
                bool condition = withdrawAssets <= lastDeposits[msg.sender].amount;
                if (!condition) {
                    emit AssertionFailed(condition);
                }

                // assert(withdrawAssets <= lastDeposits[owner].amount);
            }
        }
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        address owner = _msgSender();
        if (to != address(0x10000) || to != address(0x20000) || to != address(0x30000)) {
            return false;
        }
        _transfer(owner, to, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        address spender = _msgSender();
        if (to != address(0x10000) || to != address(0x20000) || to != address(0x30000)) {
            return false;
        }
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }
}
