//SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

import "./Referrals.sol";

interface ICard {
    function claimExternal(address owner) external returns (uint256 tokenId);
}

interface IWhiteList {
    function isInList(address account) external view returns (bool);
}

//slither-disable-next-line unprotected-upgrade
contract Seller is AccessControlEnumerableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    // using AddressList for AddressList.List;

    uint256 private constant COOLDOWN_BLOCKS = 1;

    bytes32 public constant SELLER_ROLE = keccak256("SELLER_ROLE");

    // error ZeroPrice();
    error CoolDownBaby();

    EnumerableSetUpgradeable.AddressSet private _origins;
    mapping(address => uint256) private _blocks;

    address payable private _wallet;
    ICard private _minter;
    IUniswapV2Router02 private _router; // pancakeswap router
    IERC20Upgradeable private _busd; // BUSD contract
    IERC20Upgradeable private _usdt; // USDT contract
    IERC20Upgradeable private _coin; // Coin contract

    struct Sale {
        uint64 start; // start time, unixtimstamp
        uint64 duration; // in seconds
        address wlAddress;
        bool isUSD;
        uint128 amount; // amount to sell
        uint128 remainAmount;
        uint256 price;
    }

    mapping(uint256 => Sale) private _sales;
    uint256 private _currentSaleId;

    Referrals internal _referrals; // Referrals contract

    function initialize(
        address walletAddress,
        address minterAddress,
        address referralsAddress
    ) external initializer onlyProxy {
        __ReentrancyGuard_init_unchained();
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(SELLER_ROLE, _msgSender());

        require(walletAddress != address(0), "Zerro wallet address");
        _wallet = payable(walletAddress);
        _minter = ICard(minterAddress);
        _referrals = Referrals(referralsAddress);
    }

    modifier cooldown() {
        require(_origins.add(tx.origin) || block.number > _blocks[tx.origin] + COOLDOWN_BLOCKS, "Cooldown, baby!");
        _blocks[tx.origin] = block.number;
        _;
    }

    receive() external payable {
        buyNFT(1, address(0));
    }

    function setWallet(address payable walletAddress) external {
        _checkRole(DEFAULT_ADMIN_ROLE);
        require(walletAddress != address(0), "Zerro wallet address");
        _wallet = payable(walletAddress);
    }

    function getWallet() external view returns (address) {
        return _wallet;
    }

    function getReferralsContract() external view returns (address) {
        return address(_referrals);
    }

    function setReferralsContract(address referralsAddress) external {
        _checkRole(DEFAULT_ADMIN_ROLE);
        _referrals = Referrals(referralsAddress);
    }

    function getSale(uint256 saleId) public view returns (Sale memory) {
        return _sales[saleId];
    }

    function setSale(
        uint256 saleId,
        uint64 start,
        uint64 duration,
        uint128 amount,
        address wlAddress,
        bool isUSD,
        uint256 price
    ) external onlyRole(SELLER_ROLE) {
        _sales[saleId] = Sale(start, duration, wlAddress, isUSD, amount, amount, price);
    }

    function setCurrentSaleId(uint256 saleId) external onlyRole(SELLER_ROLE) {
        _currentSaleId = saleId;
    }

    function getCurrentSale() public view returns (Sale memory) {
        return _sales[_currentSaleId];
    }

    function _getSaleAndCheck(uint256 saleId, address buyer) internal view returns (Sale memory sale) {
        sale = _sales[saleId];
        require(block.timestamp >= sale.start && (sale.duration == 0 || block.timestamp < sale.start + sale.duration), "Sale not started");
        // if (sale.start == 0 || block.timestamp < sale.start || (sale.duration != 0 && block.timestamp > sale.start + sale.duration)) revert SaleNotStarted();
        require(sale.remainAmount > 0, "sold out");
        // if (sale.remainAmount == 0) revert SoldOut();
        // if (sale.wlAddress != address(0) && !IWhiteList(sale.wlAddress).isInList(buyer)) revert OnlyWhiteLiasAllowed();
        require(sale.wlAddress == address(0) || IWhiteList(sale.wlAddress).isInList(buyer), "only whitelist");
    }

    function _getAmountCost(Sale memory sale, uint128 buyAmount) internal pure returns (uint128 amount, uint256 cost) {
        require(buyAmount > 0, "zero buy amount");
        if (buyAmount > sale.remainAmount) {
            amount = sale.remainAmount;
        } else {
            amount = buyAmount;
        }
        cost = sale.price * amount;
    }

    function _buyNFT(
        address buyer,
        uint128 buyAmount,
        uint256 saleId,
        address refUser
    ) internal {
        Sale memory sale = _getSaleAndCheck(saleId, buyer);
        (uint128 amount, uint256 cost) = _getAmountCost(sale, buyAmount);
        uint256 value;

        if (sale.isUSD) {
            revert("currency not supported");
            // uint256 bnbPrice = getBNBper1USD();
            // value = (cost * bnbPrice) / 1 ether;
        } else {
            value = cost;
        }
        require(msg.value >= value, "not enough money");

        for (uint256 i = 0; i < amount; i++) {
            _minter.claimExternal(buyer);
        }
        _sales[_currentSaleId].remainAmount -= amount;


        uint256 refReward = _referrals.calcRefReward(value);
        _referrals.regDistribute{value: refReward}(buyer,address(_coin), value,  refUser);

        (bool success, ) = _wallet.call{value: value - refReward}("");
        require(success, "failed transfer to wallet");


        // change
        if (msg.value > value) {
            //change return only to particular addresses
            payable(buyer).transfer(msg.value - value);
        }
    }

    function buyNFT(uint128 amount, address refUser) public payable nonReentrant cooldown {
        _buyNFT(_msgSender(), amount, _currentSaleId, refUser);
    }

    function buyNFTOnSale(
        uint128 amount,
        uint256 saleId,
        address refUser
    ) public payable nonReentrant cooldown {
        _buyNFT(_msgSender(), amount, saleId, refUser);
    }

    /**
     * @dev See {UUPS-_authorizeUpgrade}. Allows `DEFAULT_ADMIN_ROLE` to perform upgrade.
     */
    function _authorizeUpgrade(address) internal virtual override(UUPSUpgradeable) {
        _checkRole(DEFAULT_ADMIN_ROLE);
    }
}
