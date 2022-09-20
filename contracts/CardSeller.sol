//SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "./Card.sol";

import "./lib/ShuffleId.sol";
import "./lib/errors.sol";

contract CardSeller is AccessControlEnumerableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable {
  using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
  using ShuffleId for ShuffleId.IdMatrix;

  bytes32 public constant SALE_ROLE = keccak256("SALE_ROLE");
  uint256 private constant COOLDOWN_BLOCKS = 5;

  error ZeroPrice();
  error WrongAmountsOrder();
  error CoolDownBaby();

  // - by setting levels array it possible to sell levels with probaility of mint
  // - each amount for card means it probaility of mint
  // - sum of all amounts will be equivalent to 100%
  // - levels array and (corresponding amounts array) must be sorted in descending order by mint amount (i.e. probaility of mint)
  //   e.g.:
  //   we have 4 different levels, and want next amounts to mint:
  //   level 1 - 100, level 2 - 800, level 3 - 20, level 4 - 80
  //   that's mean: card 1 has 10% probability, card 2 - 80%, card 3 - 2%, card 4 - 8%
  //   so order of card addresses and it amounts must be: 2,1,4,3
  struct Sale {
    Card card;
    uint128[] levels; // list of mintable level ids
    uint128[] amounts; //max sale amount per level
    uint128[] remainAmounts; //remain sale amount per level (will be updated autmatically)
    uint128 totalAmount; // total amount on sale (will be updated autmatically)
    uint128 totalRemainAmount; // total sale remain amount (will be updated autmatically)
  }
  struct SaleRound {
    uint64 start; // start time, unixtimstamp
    uint64 duration; // in seconds
    uint256 price; //usd, related to Chainlink pricefeed, 1e18 = 1$
    uint128 amount; // amount to sell
    uint128 remainAmount;
  }

  EnumerableSetUpgradeable.AddressSet private _origins;
  mapping(address => uint256) private _blocks;

  address payable private _wallet;
  AggregatorV3Interface private _priceFeedBUSD; // BNB/BUSD
  IERC20Upgradeable private _tokenBUSD; // BUSD token

  Sale private _sale;
  SaleRound private _round;
  uint256 private _currentRoundId;

  function initialize(
    address payable wallet,
    address tokenBUSDAddress,
    address priceFeedBUSDAddress
  ) external initializer {
    __CardSeller_init(wallet, tokenBUSDAddress, priceFeedBUSDAddress);
  }

  function __CardSeller_init(
    address payable wallet,
    address tokenBUSDAddress,
    address priceFeedBUSDAddress
  ) internal onlyInitializing {
    __ReentrancyGuard_init_unchained();
    __CardSeller_init_unchained(wallet, tokenBUSDAddress, priceFeedBUSDAddress);
  }

  function __CardSeller_init_unchained(
    address payable wallet,
    address tokenBUSDAddress,
    address priceFeedBUSDAddress
  ) internal onlyInitializing {
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    _setupRole(SALE_ROLE, _msgSender());

    if (wallet == address(0)) revert ZeroAddress();
    _wallet = wallet;
    _tokenBUSD = IERC20Upgradeable(tokenBUSDAddress);
    _priceFeedBUSD = AggregatorV3Interface(priceFeedBUSDAddress);
  }

  modifier cooldown() {
    if (!_origins.add(tx.origin) && block.number <= _blocks[tx.origin] + COOLDOWN_BLOCKS) {
      revert CoolDownBaby();
    }
    _blocks[tx.origin] = block.number;
    _;
  }

  receive() external payable nonReentrant {
    _buy(1);
  }

  /**
   * Returns the latest BNB amount per 1USD
   */
  function getBNBper1USD() public view returns (uint256) {
    (, int256 price, , , ) = _priceFeedBUSD.latestRoundData();
    return uint256(price);
  }

  function setWallet(address payable wallet) external onlyRole(DEFAULT_ADMIN_ROLE) {
    if (wallet == address(0)) revert ZeroAddress();
    _wallet = wallet;
  }

  function getWallet() external view returns (address) {
    return _wallet;
  }

  // function setCard(address cardAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
  //   if (cardAddress == address(0)) revert ZeroAddress();
  //   _card = Card(cardAddress);
  // }

  // function getCard() external view returns (address) {
  //   return address(_card);
  // }

  function setPriceFeed(address priceFeedBUSDAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _priceFeedBUSD = AggregatorV3Interface(priceFeedBUSDAddress);
  }

  function getPriceFeed() external view returns (address) {
    return address(_priceFeedBUSD);
  }

  function getSale() public view returns (Sale memory) {
    return _sale;
  }

  function getSaleRound() public view returns (SaleRound memory, uint256) {
    return (_round, _currentRoundId);
  }

  // -  amounts array must be sorted in descending order by mint amount (i.e. probaility of mint)
  function _checkAmountsOrder(uint128[] memory amounts) internal pure returns (uint128 totalAmount) {
    uint256 prevAmount;
    for (uint256 i = 0; i < amounts.length; i++) {
      if (amounts[i] == 0) revert ZeroValue();
      if (i > 0 && amounts[i] > prevAmount) revert WrongAmountsOrder();
      totalAmount += amounts[i];
      prevAmount = amounts[i];
    }
  }

  function setupSale(
    Card card,
    uint128[] memory levels,
    uint128[] memory amounts
  ) external onlyRole(SALE_ROLE) {
    if (levels.length != amounts.length) revert WrongInputParams();
    uint128 totalAmount = _checkAmountsOrder(amounts);
    _sale = Sale(
      card,
      levels,
      amounts,
      amounts, //remainAmounts
      totalAmount,
      totalAmount //totalRmainAmount
    );
  }

  function setupSaleRound(
    uint64 start,
    uint64 duration,
    uint256 price,
    uint128 amount,
    uint256 roundId
  ) external onlyRole(SALE_ROLE) {
    if (start == 0) revert StartDateNotDefined();
    if (price == 0) revert ZeroPrice();
    if (amount == 0) revert ZeroValue();
    if (amount > _sale.totalRemainAmount) revert InsufficientAmount();

    _round = SaleRound(
      start,
      duration,
      price,
      amount,
      amount //remainAmount
    );
    _currentRoundId = roundId;
  }

  function prolongSaleRound(uint64 start, uint64 duration) external onlyRole(SALE_ROLE) {
    if (start == 0) revert StartDateNotDefined();
    _round.start = start;
    _round.duration = duration;
  }

  function closeSale() external onlyRole(SALE_ROLE) {
    delete _sale;
    delete _round;
    delete _currentRoundId;
  }

  /**
   * @dev Return random index according amounts probability
   * @return index Returned index is 1-based.
   * @notice In case of no more ammounts avail, index=0
   */
  function _getRandomLevelIndex(
    uint128 totalAmount,
    uint128[] memory amounts,
    uint128[] memory remainAmounts,
    uint256 seed
  ) internal view returns (uint256 index) {
    uint256 i;
    uint128 amountSum = 0;
    // calc random index
    uint256 random = ShuffleId.diceRoll(totalAmount + 1, seed);
    for (i = 0; i < amounts.length; i++) {
      index = i + 1; // shift index by 1 to check it for zero later
      amountSum += amounts[i];
      if (random <= amountSum) {
        break;
      }
    }
    // if finded random index has no more supply
    if (remainAmounts[i] == 0) {
      index = 0;
      // find first avail amount
      for (uint256 k = 0; k < amounts.length; k++) {
        // skip finded before random index
        if (k != i && remainAmounts[k] > 0) {
          index = k + 1;
          break;
        }
      }
    }
    // no overflow due to function call only when at least 1 in remainAmounts exists
    return index - 1; // unshift index by 1
  }

  function _getAmountPriceCost(
    Sale memory sale,
    SaleRound memory round,
    uint128 buyAmount
  ) internal pure returns (uint128 amount, uint256 cost) {
    if (buyAmount == 0) revert ZeroValue();
    amount = buyAmount;
    if (amount > sale.totalRemainAmount) {
      amount = sale.totalRemainAmount;
    }
    if (amount > round.remainAmount) {
      amount = round.remainAmount;
    }
    cost = amount * round.price;
  }

  function _getSaleRound() internal view returns (Sale memory sale, SaleRound memory round) {
    sale = _sale;
    round = _round;
    if (round.start == 0 || block.timestamp < round.start || (round.duration != 0 && block.timestamp > round.start + round.duration))
      revert SaleNotStarted();
    if (sale.totalRemainAmount == 0 || round.remainAmount == 0) revert NoMoreRemainAmount();
  }

  function _processSale(
    Sale memory sale,
    address buyer,
    uint128 amount
  ) internal returns (uint128[] memory) {
    uint256 index;
    for (uint256 i = 0; i < amount; i++) {
      // skip random index if only 1 level
      index = sale.levels.length > 1 // revert inside the _getRandomLevelIndex should not fire due to `amount <= sale.totalRemainAmount`
        ? _getRandomLevelIndex(sale.totalAmount, sale.amounts, sale.remainAmounts, uint160(buyer) + i + index)
        : 0;
      sale.card.mint(buyer, _sale.levels[index]);
      // update remain amount for card
      sale.remainAmounts[index]--;
    }
    return sale.remainAmounts;
  }

  function _buy(uint128 buyAmount) internal {
    if (msg.value == 0) revert NotEnoughMoney();
    (Sale memory sale, SaleRound memory round) = _getSaleRound();
    (uint128 amount, uint256 costBUSD) = _getAmountPriceCost(sale, round, buyAmount);

    uint256 bnbPrice = getBNBper1USD();
    uint256 value = (costBUSD * bnbPrice) / 1 ether;
    if (msg.value < value) revert NotEnoughMoney();

    // process and update remain amounts
    _sale.remainAmounts = _processSale(sale, _msgSender(), amount);

    // update total remain amount
    _sale.totalRemainAmount -= amount;
    _round.remainAmount -= amount;

    // change
    if (msg.value > value) {
      //change return only to particular addresses
      payable(_msgSender()).transfer(msg.value - value);
    }
    // pass all remaining gas in case of wallet is contract
    (bool success, ) = _wallet.call{value: address(this).balance}("");
    if (!success) revert FailedToTransferMoney();
  }

  function _buyForUSD(uint128 buyAmount) internal {
    (Sale memory sale, SaleRound memory round) = _getSaleRound();
    (uint128 amount, uint256 costBUSD) = _getAmountPriceCost(sale, round, buyAmount);
    // process and update remain amounts
    _sale.remainAmounts = _processSale(sale, _msgSender(), amount);
    _tokenBUSD.transferFrom(_msgSender(), _wallet, costBUSD);
    // update total remain amount
    _sale.totalRemainAmount -= amount;
    _round.remainAmount -= amount;
  }

  function buy() public payable nonReentrant cooldown {
    _buy(1);
  }

  function buyForUSD() public nonReentrant cooldown {
    _buyForUSD(1);
  }

  /**
   * @dev See {UUPS-_authorizeUpgrade}. Allows `DEFAULT_ADMIN_ROLE` to perform upgrade.
   */
  function _authorizeUpgrade(address) internal virtual override(UUPSUpgradeable) {
    _checkRole(DEFAULT_ADMIN_ROLE, _msgSender());
  }
}
