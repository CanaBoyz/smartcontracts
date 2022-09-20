//SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./Coin.sol";
import "./Market.sol";

contract DepositWallet is AccessControlEnumerableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    event Withdraw(address indexed user, uint256 amount);

    Coin private _coin; // Coin contract
    mapping(address => uint256) private _balances;
    address payable private _wallet;
    Market private _market;
    uint16 private _withdrawFee;

    function initialize(
        address coinAddress,
        address walletAddress,
        address marketAddress,
        uint16 withdrawFee
    ) external initializer onlyProxy {
        __ReentrancyGuard_init_unchained();

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(OPERATOR_ROLE, _msgSender());

        _coin = Coin(coinAddress);
        _wallet = payable(walletAddress);
        _market = Market(marketAddress);
        _withdrawFee = withdrawFee;
    }

    function setWallet(address walletAddress) external {
        _checkRole(DEFAULT_ADMIN_ROLE);
        require(walletAddress != address(0), "Zerro wallet address");
        _wallet = payable(walletAddress);
    }

    function getWallet() external view returns (address) {
        return _wallet;
    }

    function setMarketContract(address marketAddress) external {
        _checkRole(DEFAULT_ADMIN_ROLE);
        require(marketAddress != address(0), "Zerro market address");
        _market = Market(marketAddress);
    }

    function getMerketContract() external view returns (address) {
        return address(_market);
    }

    function setWithdrawFee(uint16 withdrawFee) external {
        _checkRole(OPERATOR_ROLE);
        _withdrawFee = withdrawFee;
    }

    function getWithdrawFee() external view returns (uint256) {
        return _withdrawFee;
    }

    function balanceOf(address user) external view returns (uint256) {
        return _balances[user];
    }

    function deposit(address user, uint256 amount) external {
        require(user != address(0), "Zerro user address");
        _coin.transferFrom(_msgSender(), address(this), amount);
        _balances[user] += amount;
    }

    function _withdraw(
        address user,
        uint256 amount,
        uint16 fee
    ) internal {
        require(amount > 0, "Zero amount");
        uint256 balance = _balances[user];
        require(balance >= amount, "Insuficient balance");
        unchecked {
            _balances[user] = balance - amount;
        }

        uint256 feeAmount = (amount * fee) / 10000;
        if (feeAmount > 0) {
            _coin.transferFrom(address(this), _wallet, feeAmount);
        }
        _coin.transferFrom(address(this), user, amount - feeAmount);
        emit Withdraw(user, amount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        _withdraw(_msgSender(), amount, _withdrawFee);
    }

    function withdrawFor(address user, uint256 amount) external nonReentrant {
        _checkRole(OPERATOR_ROLE);
        _withdraw(user, amount, 0);
    }

    function buyShopItems(uint256[] memory ids, uint256[] memory amounts) external nonReentrant {
        address user = _msgSender();
        // shopId = 1
        uint256 amount = _market.buyShopItemsCoinFor(1, ids, amounts, user);
        uint256 balance = _balances[user];
        require(balance >= amount, "Insuficient balance");
        unchecked {
            _balances[user] = balance - amount;
        }
    }

    /**
     * @dev See {UUPS-_authorizeUpgrade}. Allows `DEFAULT_ADMIN_ROLE` to perform upgrade.
     */
    function _authorizeUpgrade(address) internal virtual override(UUPSUpgradeable) {
        _checkRole(DEFAULT_ADMIN_ROLE);
    }
}
