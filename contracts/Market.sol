// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "./lib/ERC721Receiver.sol";
import "./lib/ERC1155Receiver.sol";
import "./lib/AmountStore.sol";
import "./lib/errors.sol";
import "./Item.sol";
import "./Shop.sol";
import "./Coin.sol";
import "./InnerCoin.sol";

import "./Referrals.sol";

/**
 * @dev Market
 */
contract Market is AccessControlEnumerableUpgradeable, UUPSUpgradeable, ERC721Receiver, ERC1155Receiver {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;
    using AmountStore for AmountStore.Store;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    event BuyItems(uint256 shop, address buyer, uint256[] ids, uint256[] amounts);
    event MintItems(uint256 shop, uint256[] ids, uint256[] amounts);
    event BurnItems(uint256 shop, uint256[] ids, uint256[] amounts);
    event AddSItems(uint256 shop, address from, uint256[] ids, uint256[] amounts);
    event DelItems(uint256 shop, address to, uint256[] ids, uint256[] amounts);

    struct ShopStore {
        uint16 feeBuy;
        uint16 feeSel;
        AmountStore.Store items;
    }

    struct ItemPrice {
        uint128 buyPriceUSD;
        uint128 sellPriceUSD;
    }

    Item private _item;
    Shop private _shop;
    Coin private _coin;
    InnerCoin private _innerCoin;

    address payable private _wallet;
    Referrals internal _referrals; // Referrals contract

    IUniswapV2Router02 private _router; // pancakeswap router
    IERC20 private _busd; // BUSD token

    //shopId => Store
    mapping(uint256 => ShopStore) private _stores;

    //itemId => Prices
    mapping(uint256 => ItemPrice) private _prices;

    function initialize(
        address payable walletAddress,
        address itemAddress,
        address shopAddress,
        address coinAddress,
        address innerCoinAddress,
        address busdAddress,
        address routerAddress,
        address referralsAddress
    ) external initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MANAGER_ROLE, _msgSender());

        _item = Item(itemAddress);
        _shop = Shop(shopAddress);
        _coin = Coin(coinAddress);
        _innerCoin = InnerCoin(innerCoinAddress);

        _router = IUniswapV2Router02(routerAddress);
        _busd = IERC20(busdAddress);

        require(walletAddress != address(0), "Zerro wallet address");
        _wallet = walletAddress;
        _referrals = Referrals(referralsAddress);
    }

    /**
     * @dev Get the market contract address
     */
    function getItemContract() external view returns (address) {
        return address(_item);
    }

    function getShopContract() external view returns (address) {
        return address(_shop);
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

    function setItemContract(address itemAddress) external {
        _checkRole(DEFAULT_ADMIN_ROLE);
        _item = Item(itemAddress);
    }

    function setShopContract(address shopAddress) external {
        _checkRole(DEFAULT_ADMIN_ROLE);
        _shop = Shop(shopAddress);
    }

    function setCoinContract(address coinAddress) external {
        _checkRole(DEFAULT_ADMIN_ROLE);
        _coin = Coin(coinAddress);
    }

    function setInnerCoinContract(address innerCoinAddress) external {
        _checkRole(DEFAULT_ADMIN_ROLE);
        _innerCoin = InnerCoin(innerCoinAddress);
    }

    function setBUSDContract(address busdAddress) external {
        _checkRole(DEFAULT_ADMIN_ROLE);
        _busd = IERC20(busdAddress);
    }

    function getTokenPair() external view returns (address coinAddress, address busdAddress) {
        return (address(_coin), address(_busd));
    }

    /**
     * Returns the latest BNB amount per 1USD
     */
    function getBNBPer1USD() public view returns (uint256) {
        return _getAmountPerUSD(_router.WETH(), 1 ether);
    }

    function getBNBAmountPerUSD(uint256 cost) public view returns (uint256) {
        return (getBNBPer1USD() * cost) / 1 ether;
    }

    function getCoinPer1USD() public view returns (uint256 cost) {
        cost = _getAmountPerUSD(address(_coin), 1 ether);
        //return hardcoded price until pool exists
        if (cost == 0) return 12500 ether;
    }

    function getCoinAmountPerUSD(uint256 cost) public view returns (uint256) {
        return (getCoinPer1USD() * cost) / 1 ether;
    }

    function _getAmountPerUSD(address token, uint256 cost) internal view returns (uint256) {
        if (IUniswapV2Factory(_router.factory()).getPair(token, address(_busd)) == address(0)) return 0;
        address[] memory path = _getPairPath(token, address(_busd));
        uint256[] memory amounts = _router.getAmountsIn(cost, path);
        return uint256(amounts[0]);
    }

    function _getPairPath(address token0, address token1) internal pure returns (address[] memory path) {
        path = new address[](2);
        path[0] = token0;
        path[1] = token1;
    }

    // function getTokenAmountPer1USD() public view returns (uint256) {
    //     return getTokenAmountFromUSD(1 ether);
    // }

    // function getTokenAmountFromUSD(uint256 amountUSD) public view returns (uint256) {
    //     address[] memory path = new address[](2);
    //     path[0] = address(_coin);
    //     path[1] = address(_coinBUSD);
    //     uint256[] memory tokenAmounts = _router.getAmountsIn(amountUSD, path);
    //     return tokenAmounts[0];
    // }

    function getItemPrice(uint256 itemId) external view returns (ItemPrice memory) {
        return _prices[itemId];
    }

    function setItemPrice(uint256 itemId, ItemPrice memory price) external {
        _checkRole(MANAGER_ROLE);
        _prices[itemId] = price;
    }

    function getItemsPrices(uint256[] memory ids) external view returns (ItemPrice[] memory prices) {
        prices = new ItemPrice[](ids.length);
        for (uint256 i = 0; i < ids.length; ++i) {
            prices[i] = _prices[ids[i]];
        }
    }

    function setItemsPrices(uint256[] memory ids, ItemPrice[] memory prices) external {
        _checkRole(MANAGER_ROLE);
        for (uint256 i = 0; i < ids.length; ++i) {
            _prices[ids[i]] = prices[i];
        }
    }

    function getShopFee(uint256 shopId) external view returns (uint256, uint256) {
        // require(_exists(tokenId), "Shop: state query for nonexistent shop");
        return (_stores[shopId].feeBuy, _stores[shopId].feeSel);
    }

    function setShopFee(
        uint256 shopId,
        uint8 feeBuy,
        uint8 feeSel
    ) external {
        address owner = _shop.ownerOf(shopId);
        if (_msgSender() != owner) revert CallerIsNotOwner();
        _stores[shopId].feeBuy = feeBuy;
        _stores[shopId].feeSel = feeSel;
    }

    event ShopOpen(address indexed owner, uint256 indexed shopId);
    event ShopClose(address indexed owner, uint256 indexed shopId);

    function openShop(address owner) external {
        _checkRole(MANAGER_ROLE);
        uint256 shopId = _shop.mint(owner);
        emit ShopOpen(owner, shopId);
    }

    function closeShop(uint256 shopId) external {
        _checkRole(MANAGER_ROLE);
        address owner = _shop.ownerOf(shopId);
        // if (_msgSender() != owner) revert CallerIsNotOwner();
        _shop.burn(shopId);
        emit ShopClose(owner, shopId);
    }

    function mintShopItems(
        uint256 shopId,
        uint256[] memory ids,
        uint256[] memory amounts
    ) external {
        _checkRole(MANAGER_ROLE);
        _addItemsToShop(shopId, ids, amounts);
        _item.mintBatch(address(this), ids, amounts);
    }

    function burnShopItems(
        uint256 shopId,
        uint256[] memory ids,
        uint256[] memory amounts
    ) external {
        _checkRole(MANAGER_ROLE);
        _removeItemFromShop(shopId, ids, amounts);
        _item.burnBatch(address(this), ids, amounts);
    }

    function _addItemsToShop(
        uint256 shopId,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal {
        if (ids.length == 0) revert EmptyInput();
        _stores[shopId].items.add(AmountStore.Bundle(ids, amounts));
    }

    function _removeItemFromShop(
        uint256 shopId,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal {
        if (ids.length == 0) revert EmptyInput();
        _stores[shopId].items.sub(AmountStore.Bundle(ids, amounts));
    }

    function getItemsCostUSD(uint256[] memory ids, uint256[] memory amounts) public view returns (uint256 cost) {
        if (ids.length == 0) revert EmptyInput();
        for (uint256 i = 0; i < ids.length; ++i) {
            unchecked {
                cost += amounts[i] * _prices[ids[i]].buyPriceUSD;
            }
        }
    }

    function getItemsCostCoin(uint256[] memory ids, uint256[] memory amounts) public view returns (uint256) {
        return getCoinAmountPerUSD(getItemsCostUSD(ids, amounts));
    }

    function getItemsCostBNB(uint256[] memory ids, uint256[] memory amounts) public view returns (uint256) {
        return getBNBAmountPerUSD(getItemsCostUSD(ids, amounts));
    }

    function _buyShopItemsCoin(
        uint256 shopId,
        uint256[] memory ids,
        uint256[] memory amounts,
        address payer,
        address recipient
    ) internal returns (uint256 cost) {
        address owner = _shop.ownerOf(shopId);
        cost = getItemsCostCoin(ids, amounts);

        if (cost > 0) {
            uint256 fee = (cost * _stores[shopId].feeBuy) / 10000;
            if (fee > 0) {
                _coin.transferFrom(payer, owner, fee);
            }
            _coin.transferFrom(payer, _wallet, cost - fee);
        }

        _removeItemFromShop(shopId, ids, amounts);
        _item.safeBatchTransferFrom(address(this), recipient, ids, amounts, "");
    }

    function _buyShopItemsBNB(
        uint256 shopId,
        uint256[] memory ids,
        uint256[] memory amounts,
        address payer,
        address recipient,
        address refUser
    ) internal returns (uint256 cost) {
        address payable owner = payable(_shop.ownerOf(shopId));
        cost = getItemsCostBNB(ids, amounts);
        if (msg.value < cost) revert NotEnoughMoney();

        if (cost > 0) {
            uint256 fee = (cost * _stores[shopId].feeBuy) / 10000;
            if (fee > 0) {
                owner.transfer(fee);
            }

            uint256 refReward = _referrals.calcRefReward(cost);
            _referrals.regDistribute{value: refReward}(recipient, address(0), cost, refUser);

            (bool success, ) = _wallet.call{value: cost - fee - refReward}("");
            require(success, "failed transfer to wallet");
        }

        _removeItemFromShop(shopId, ids, amounts);
        _item.safeBatchTransferFrom(address(this), recipient, ids, amounts, "");
        // change
        if (msg.value > cost) {
            //change return only to particular addresses
            payable(payer).transfer(msg.value - cost);
        }
    }

    function buyShopItemsCoin(
        uint256 shopId,
        uint256[] memory ids,
        uint256[] memory amounts
    ) external returns (uint256) {
        return _buyShopItemsCoin(shopId, ids, amounts, _msgSender(), _msgSender());
    }

    function buyShopItemsBNB(
        uint256 shopId,
        uint256[] memory ids,
        uint256[] memory amounts,
        address refUser
    ) external payable returns (uint256) {
        return _buyShopItemsBNB(shopId, ids, amounts, _msgSender(), _msgSender(), refUser);
    }

    function buyShopItemsCoinFor(
        uint256 shopId,
        uint256[] memory ids,
        uint256[] memory amounts,
        address recipient
    ) external returns (uint256) {
        return _buyShopItemsCoin(shopId, ids, amounts, _msgSender(), recipient);
    }

    function shopItemsCount(uint256 shopId) external view returns (uint256) {
        return _stores[shopId].items.len();
    }

    function shopItemByIndex(uint256 shopId, uint256 index) external view returns (uint256 id, uint256 amount) {
        return _stores[shopId].items.at(index);
    }

    function shopItems(uint256 shopId) external view returns (AmountStore.Bundle memory) {
        return _stores[shopId].items.get();
    }

    function shopItemAmount(uint256 shopId, uint256 itemId) external view returns (uint256) {
        return _stores[shopId].items.val(itemId);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlEnumerableUpgradeable, ERC721Receiver, ERC1155Receiver)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {UUPS-_authorizeUpgrade}. Allows `DEFAULT_ADMIN_ROLE` to perform upgrade.
     */
    function _authorizeUpgrade(address) internal virtual override(UUPSUpgradeable) {
        _checkRole(DEFAULT_ADMIN_ROLE);
    }
}
