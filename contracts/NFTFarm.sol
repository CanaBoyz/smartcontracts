//SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";

import "./NFT.sol";
import "./Coin.sol";
import "./WhiteList.sol";
import "./DepositWallet.sol";

contract NFTFarm is AccessControlEnumerableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable {
  using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;
  using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
  using SafeCastUpgradeable for uint256;

  bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

  event Staked(address indexed farmer, uint256 nftId);
  event Unstaked(address indexed farmer, uint256 nftId);
  event Claimed(address indexed farmer, uint256 amount);

  struct FarmerState {
    uint64 enterAt;
    uint64 exitAt;
    uint64 claimAt;
    uint256 shares;
    uint256 claimedAmount;
  }

  struct GlobalState {
    uint64 startAt;
    uint64 endAt;
    uint64 updateAt;
    uint256 totalShares;
    uint256 totalAmount;
    uint256 reservedAmount;
    uint256 claimedAmount;
  }

  struct FarmParams {
    uint256 periodYield; //tokens per user per period, e.g. 4_000 * 10**18
    uint64 farmPeriod; // period, e.g. 1 days
    uint64 stopDate; // yielding end date
  }

  Coin private _coin; // Coin contract
  NFT private _nft; // NFT contract
  DepositWallet private _depositWallet;

  FarmParams private _farmParams;

  EnumerableSetUpgradeable.AddressSet private _farmers;
  mapping(address => FarmerState) private _farmerStates;
  mapping(address => EnumerableSetUpgradeable.UintSet) private _farmerNFTs;
  GlobalState private _globalState;

  function initialize(
    address coinAddress,
    address nftAddress,
    address depositWallet,
    uint256 periodYield,
    uint64 farmPeriod,
    uint64 stopDate
  ) external initializer onlyProxy {
    __ReentrancyGuard_init_unchained();

    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    _setupRole(OPERATOR_ROLE, _msgSender());

    _coin = Coin(coinAddress);
    _nft = NFT(nftAddress);
    _depositWallet = DepositWallet(depositWallet);

    // _periodYield = periodYield;
    // _farmPeriod = farmPeriod;

    _farmParams = FarmParams(periodYield, farmPeriod, stopDate);
    // _stopDate = stopDate;
    // _periodYield = 4_000;
    // _farmPeriod = 600;
  }

  function getCoinAddress() external view returns (address) {
    return address(_coin);
  }

  function getNFTAddress() external view returns (address) {
    return address(_nft);
  }

  function setCoinAddress(address coinAddress) external {
    _checkRole(DEFAULT_ADMIN_ROLE);
    _coin = Coin(coinAddress);
  }

  function setNFTAddress(address nftAddress) external {
    _checkRole(DEFAULT_ADMIN_ROLE);
    _nft = NFT(nftAddress);
  }

  function getFarmParams() public view returns (FarmParams memory params) {
    params = _farmParams;
    params.periodYield = params.periodYield;
  }

  function getGlobalState() public view returns (GlobalState memory globalState) {
    globalState = _globalState;
    globalState.totalAmount = globalState.totalAmount;
    globalState.claimedAmount = globalState.claimedAmount;
    globalState.reservedAmount = globalState.reservedAmount;
  }

  function getFarmers() public view returns (address[] memory) {
    return _farmers.values();
  }

  function getFarmerState(address farmer) public view returns (FarmerState memory state) {
    state = _farmerStates[farmer];
    state.claimedAmount = state.claimedAmount;
  }

  function getFarmerNFTs(address farmer) public view returns (uint256[] memory) {
    return _farmerNFTs[farmer].values();
  }

  function getNFTYieldShares(uint256 nftId) public pure returns (uint256) {
    return 1 << (_getLevelIndex(nftId));
  }

  function getNFTPeriodYield(uint256 nftId) public view returns (uint256) {
    return (_farmParams.periodYield * getNFTYieldShares(nftId));
  }

  function _getNow() internal view returns (uint64) {
    return uint64(block.timestamp);
  }

  function refill(uint256 amount) external {
    _checkRole(OPERATOR_ROLE);
    require(amount > 0, "Farm: zero refill amount");

    _coin.transferFrom(_msgSender(), address(this), amount);

    uint64 refillAt = _getNow();
    GlobalState memory globalState = _globalState;

    if (globalState.startAt == 0) {
      globalState.startAt = refillAt;
    }

    if (globalState.updateAt == 0) {
      globalState.updateAt = refillAt;
    }

    globalState.totalAmount += amount;

    if (globalState.totalShares > 0) {
      _updGlobalTotlaSharesAndEndAt(globalState, 0, false);
      if (refillAt > globalState.endAt) {
        refillAt = globalState.endAt;
      }
      _updGlobalReservedAmount(globalState, refillAt);
    }

    _globalState = globalState;
  }

  function drain() external {
    _checkRole(OPERATOR_ROLE);
    GlobalState memory globalState = _globalState;
    uint64 drainAt = _getNow();

    if (globalState.totalShares > 0) {
      if (drainAt > globalState.endAt) {
        drainAt = globalState.endAt;
      }
      _updGlobalReservedAmount(globalState, drainAt);
    }
    uint256 amount = _coin.balanceOf(address(this)) - (globalState.reservedAmount - globalState.claimedAmount);
    require(amount > 0, "Farm: zero drain amount");

    globalState.totalAmount = globalState.reservedAmount;
    _updGlobalTotlaSharesAndEndAt(globalState, 0, false);

    if (globalState.totalAmount == 0) {
      // nobody yet started farming
      globalState.startAt = 0;
      globalState.updateAt = 0;
    }

    _coin.transfer(_msgSender(), amount);
    _globalState = globalState;
  }

  function setStopDate(uint64 stopDate) external {
    _checkRole(OPERATOR_ROLE);
    GlobalState memory globalState = _globalState;
    require(stopDate == 0 || stopDate > globalState.updateAt, "Farm: wrong stop date");
    _farmParams.stopDate = stopDate;
    _updGlobalTotlaSharesAndEndAt(globalState, 0, false);
    _globalState = globalState;
  }

  /// @dev !!! danger !!!
  // function setFarmParams(uint256 periodYield, uint64 farmPeriod) external {
  //   _checkRole(OPERATOR_ROLE);
  //   _periodYield = periodYield;
  //   _farmPeriod = farmPeriod;
  // }

  function enter(uint256 nftId) external {
    address farmer = _msgSender();
    _enter(farmer, nftId);
  }

  function enterBatch(uint256[] memory nftIds) external {
    address farmer = _msgSender();
    require(nftIds.length > 0, "Farm: empty NFTs list");
    for (uint256 i = 0; i < nftIds.length; ++i) {
      _enter(farmer, nftIds[i]);
    }
  }

  function exitFor(address farmer, uint256 nftId) external {
    _checkRole(OPERATOR_ROLE);
    _exit(farmer, nftId);
  }

  function exitBatchFor(address farmer, uint256[] memory nftIds) external {
    _checkRole(OPERATOR_ROLE);
    require(nftIds.length > 0, "Farm: empty NFTs list");
    for (uint256 i = 0; i < nftIds.length; ++i) {
      _exit(farmer, nftIds[i]);
    }
  }

  function exitAllFor(address farmer) external {
    _checkRole(OPERATOR_ROLE);
    uint256[] memory nftIds = _farmerNFTs[farmer].values();
    require(nftIds.length > 0, "Farm: no farmed NFTs found");
    for (uint256 i = 0; i < nftIds.length; ++i) {
      _exit(farmer, nftIds[i]);
    }
  }

  function exit(uint256 nftId) external {
    address farmer = _msgSender();
    _exit(farmer, nftId);
  }

  function exitBatch(uint256[] memory nftIds) external {
    address farmer = _msgSender();
    require(nftIds.length > 0, "Farm: empty NFTs list");
    for (uint256 i = 0; i < nftIds.length; ++i) {
      _exit(farmer, nftIds[i]);
    }
  }

  function exitAll() external {
    address farmer = _msgSender();
    uint256[] memory nftIds = _farmerNFTs[farmer].values();
    require(nftIds.length > 0, "Farm: no farmed NFTs found");
    for (uint256 i = 0; i < nftIds.length; ++i) {
      _exit(farmer, nftIds[i]);
    }
  }

  function yieldFor(address farmer) external {
    _yield(farmer);
  }

  function yield() external {
    address farmer = _msgSender();
    _yield(farmer);
  }

  function getProvisionTotalAmounts() public view returns (uint256 available, uint256 reserved) {
    uint64 provisionAt = _getNow();
    GlobalState memory globalState = _globalState;

    if (globalState.endAt > 0) {
      if (provisionAt > globalState.endAt) {
        provisionAt = globalState.endAt;
      }
      _updGlobalReservedAmount(globalState, provisionAt);
    }
    return ((globalState.totalAmount - globalState.reservedAmount), globalState.reservedAmount);
  }

  function getProvisionYieldAmount(address farmer) public view returns (uint256 yieldAmount) {
    GlobalState memory globalState = _globalState;
    FarmerState memory state = _farmerStates[farmer];
    uint64 provisionAt = _getNow();
    if (globalState.startAt > 0 && state.claimAt > 0) {
      if (provisionAt > globalState.endAt) {
        provisionAt = globalState.endAt;
      }
      if (provisionAt > state.claimAt) {
        yieldAmount = _calcAmount(provisionAt - state.claimAt, state.shares);
      }
    }
  }

  function getProvisionYieldDuration() public view returns (uint256) {
    uint64 provisionAt = _getNow();
    uint64 endAt = _globalState.endAt;
    return endAt > provisionAt ? endAt - provisionAt : 0;
  }

  function _enter(address farmer, uint256 nftId) internal {
    GlobalState memory globalState = _globalState;
    uint64 enterAt = _getNow();

    require(globalState.startAt > 0, "Farm: farming not yet started");
    require(globalState.endAt == 0 || enterAt < globalState.endAt, "Farm: faarming already ended");

    _farmers.add(farmer);
    require(_farmerNFTs[farmer].add(nftId), "Farm: NFT already farmed");

    _nft.transferFrom(farmer, address(this), nftId);
    emit Staked(farmer, nftId);

    FarmerState memory state = _farmerStates[farmer];
    uint256 shares = getNFTYieldShares(nftId);

    if (globalState.endAt == 0) {
      //1stest entered in farm
      globalState.updateAt = enterAt;
    }
    if (state.claimAt == 0) {
      // if it our 1st enter
      state.claimAt = enterAt;
    }

    _updGlobalReservedAmount(globalState, enterAt);
    _updClaimedAmountAndClaim(globalState, state, enterAt, farmer);
    _updGlobalTotlaSharesAndEndAt(globalState, shares, true);
    require(globalState.endAt > enterAt, "Farm: no availiable amount to farm");

    if (state.shares == 0) {
      state.enterAt = enterAt;
      state.exitAt = 0;
    }
    state.shares += shares;

    _globalState = globalState;
    _farmerStates[farmer] = state;
  }

  function _exit(address farmer, uint256 nftId) internal {
    require(_farmers.contains(farmer), "Farm: farmer not found");
    require(_farmerNFTs[farmer].remove(nftId), "Farm: NFT not farmed");

    _nft.transferFrom(address(this), farmer, nftId);
    emit Unstaked(farmer, nftId);

    if (_farmerNFTs[farmer].length() == 0) {
      _farmers.remove(farmer);
    }

    uint64 exitAt = _getNow();
    GlobalState memory globalState = _globalState;
    FarmerState memory state = _farmerStates[farmer];

    uint256 shares = getNFTYieldShares(nftId);

    // adjust updateAt to endAt
    if (exitAt > globalState.endAt) {
      exitAt = globalState.endAt;
    }

    _updGlobalReservedAmount(globalState, exitAt);
    _updClaimedAmountAndClaim(globalState, state, exitAt, farmer);
    _updGlobalTotlaSharesAndEndAt(globalState, shares, false);

    state.shares -= shares;
    if (state.shares == 0) {
      state.claimAt = 0;
      state.enterAt = 0;
      state.exitAt = exitAt;
    }

    _globalState = globalState;
    _farmerStates[farmer] = state;
  }

  function _yield(address farmer) internal {
    require(_farmers.contains(farmer), "Farm: farmer not found");
    uint64 yieldAt = _getNow();
    GlobalState memory globalState = _globalState;
    FarmerState memory state = _farmerStates[farmer];

    require(globalState.startAt > 0, "Farm: farming not yet started");
    require(state.enterAt > 0, "Farm: nothing to yield");
    require(yieldAt > state.claimAt, "Farm: not yet time to yield");

    // adjust updateAt to endAt
    if (yieldAt > globalState.endAt) {
      yieldAt = globalState.endAt;
    }

    _updGlobalReservedAmount(globalState, yieldAt);
    _updClaimedAmountAndClaim(globalState, state, yieldAt, farmer);

    _globalState = globalState;
    _farmerStates[farmer] = state;
  }

  function _updGlobalReservedAmount(GlobalState memory globalState, uint64 _now) internal view {
    // when call globalState.totalShares should be > 0
    if (_now > globalState.updateAt) {
      // сколько всего юзеры склаймят за период с моента последнего апдейта
      uint256 totalYieldAmount = _calcAmount(_now - globalState.updateAt, globalState.totalShares);
      globalState.updateAt = _now;
      globalState.reservedAmount += totalYieldAmount;
    }
  }

  function _updClaimedAmountAndClaim(
    GlobalState memory globalState,
    FarmerState memory state,
    uint64 _now,
    address farmer
  ) internal returns (uint256 yieldAmount) {
    // when call globalState.totalShares should be > 0
    if (_now > state.claimAt) {
      //auto claim yield
      yieldAmount = _calcAmount(_now - state.claimAt, state.shares);
      state.claimAt = _now;
      state.claimedAmount += yieldAmount;
      globalState.claimedAmount += yieldAmount;
      // rounding correction
      if (globalState.claimedAmount > globalState.reservedAmount) {
        globalState.reservedAmount = globalState.claimedAmount;
      }

      if (yieldAmount > 0) {
        // _coin.transferFrom(address(this), farmer, yieldAmount);
        _depositWallet.deposit(farmer, yieldAmount);
        emit Claimed(farmer, yieldAmount);
      }
    }
  }

  function _updGlobalTotlaSharesAndEndAt(
    GlobalState memory globalState,
    uint256 newShares,
    bool isEnter
  ) internal view {
    if (newShares > 0) {
      if (isEnter) {
        globalState.totalShares += newShares;
      } else {
        globalState.totalShares -= newShares;
      }
    }
    if (globalState.totalShares == 0) {
      globalState.endAt = 0;
    } else {
      // upd endAt with new totalShares and reservedAmount
      globalState.endAt = _calcEndAt(globalState.updateAt + _calcPeriod(globalState.totalAmount - globalState.reservedAmount, globalState.totalShares));
    }
  }

  function _calcAmount(uint64 period, uint256 shares) internal view returns (uint256) {
    return MathUpgradeable.mulDiv(_farmParams.periodYield * shares, period, _farmParams.farmPeriod);
  }

  function _calcPeriod(uint256 amount, uint256 shares) internal view returns (uint64) {
    return MathUpgradeable.mulDiv(amount, _farmParams.farmPeriod, _farmParams.periodYield * shares).toUint64();
  }

  function _calcEndAt(uint64 endAt) internal view returns (uint64) {
    uint64 stopDate = _farmParams.stopDate;
    if (stopDate == 0) return endAt;
    return MathUpgradeable.min(stopDate, endAt).toUint64();
  }

  function _getLevelIndex(uint256 nftId) internal pure returns (uint256) {
    // Gold (level 4): персонаж типа Boss рандомной фракции
    // RU BOSS 626-1250
    // JP BOSS 3126-3750
    // AF BOSS 5626-6250
    // IT BOSS 8126-8750
    // Silver  (level 3): персонаж типа Fighter рандомной фракции
    // RU FIGHTER 1251-1875
    // JP FIGHTER 3751-4375
    // AF FIGHTER 6251-6875
    // IT FIGHTER 8751-9375
    // Bronze  (level 2): персонаж типа Seller рандомной фракции
    // RU SELLER 1876-2500
    // JP SELLER 4376-5000
    // AF SELLER 6876-7500
    // IT SELLER 9376-10000
    // Common  (level 1): персонаж типа Grover рандомной фракции
    // RU GROWER 1-625
    // JP GROWER 2501-3125
    // AF GROWER 5001-5625
    // IT GROWER 7501-8125

    require(nftId > 0 && nftId <= 10000, "Farm: wrong NFT ID");
    uint256 index = ((nftId - 1) % 2500) / 625;

    if (index == 0) {
      return 0;
    }
    return 4 - index;
  }

  /**
   * @dev See {UUPS-_authorizeUpgrade}. Allows `DEFAULT_ADMIN_ROLE` to perform upgrade.
   */
  function _authorizeUpgrade(address) internal virtual override(UUPSUpgradeable) {
    _checkRole(DEFAULT_ADMIN_ROLE, _msgSender());
  }
}
