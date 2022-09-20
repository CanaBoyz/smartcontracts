// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "./lib/ERC721Receiver.sol";
import "./lib/ERC1155Receiver.sol";
import "./lib/AmountStore.sol";
import "./lib/ShuffleId.sol";
import "./lib/errors.sol";
import "./Item.sol";
import "./InnerCoin.sol";
import "./Plant.sol";

// import "hardhat/console.sol";
/**
 * @dev Lab
 */
contract Lab is AccessControlEnumerableUpgradeable, UUPSUpgradeable, ERC721Receiver, ERC1155Receiver {
    using AmountStore for AmountStore.Store;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    event Seed(address indexed owner, uint256 indexed plantId, uint8 seedType);
    event Harvest(address indexed owner, uint256 indexed plantId, uint256 amount);
    event Recycle(address indexed owner, uint256 indexed plantId, uint256 seedCount);
    // event Boost(address indexed owner, uint256 indexed plantId, uint16 profitBoost, uint16 maturationBoost);

    // Seed, // 1
    // Pot, // 2
    // Lamp, // 3
    // Box, // 4
    // Fertilizer, // 5
    // Autowatering, // 6
    // Heating, // 7
    uint256 internal constant ITEM_ID_SEED = 1; //1
    uint256 internal constant ITEM_ID_POT = 2; //2
    uint256 internal constant ITEM_ID_LAMP = 3; //3
    uint256 internal constant ITEM_ID_BOX = 4; //4
    uint256 internal constant ITEM_ID_FERTILIZER = 5; //5
    uint256 internal constant ITEM_ID_AUTOWATERING = 6; //6
    uint256 internal constant ITEM_ID_HEATING = 7; //7

    uint256 internal constant BOOST_MASK_SEED = uint256(1) << (ITEM_ID_SEED - 1); //0x1
    uint256 internal constant BOOST_MASK_POT = uint256(1) << (ITEM_ID_POT - 1); //0x2; //2
    uint256 internal constant BOOST_MASK_LAMP = uint256(1) << (ITEM_ID_LAMP - 1); //0x4; //3
    uint256 internal constant BOOST_MASK_BOX = uint256(1) << (ITEM_ID_BOX - 1); //0x8; //4
    uint256 internal constant BOOST_MASK_FERTILIZER = uint256(1) << (ITEM_ID_FERTILIZER - 1); //0x10; //5
    uint256 internal constant BOOST_MASK_WATERING = uint256(1) << (ITEM_ID_AUTOWATERING - 1); //0x20; //6
    uint256 internal constant BOOST_MASK_HEATER = uint256(1) << (ITEM_ID_HEATING - 1); //0x40; //7

    // seed type
    // Blueberry: 1
    // Amnezia Haze: 2
    // AK-47: 3
    // L.S.D.: 4
    // Lemon Haze: 5
    // Pablo Escobar: 6

    // rarity probability
    //
    // Blueberry: 50%
    // Amnezia Haze: 25%
    // AK-47: 10%
    // L.S.D.: 8.5%
    // Lemon Haze: 5%
    // Pablo Escobar: 1.5%
    //
    // encoding to hex uint32 and pack into uint256
    //  1% == 10, i.e. 50% = 500, 8.5% = 85, 100% = 1000
    //  dec:             15       50       85      100      250      500
    //  hex:    0x 0000000F 00000032 00000055 00000064 000000FA 000001F4
    //  seed type: 6        5        4        3        2        1
    uint256 private constant SEED_RARITIES = 0x0000000F000000320000005500000064000000FA000001F4;
    // yeld maturation days, min - max
    //
    // Blueberry: 10-30
    // Amnezia Haze: 25-40
    // AK-47: 25-70
    // L.S.D.: 45-90
    // Lemon Haze: 60-110
    // Pablo Escobar: 90-150

    // encoding to hex uint32(uint16+uint16) and pack into uint256
    //  dec:         47   12    54     9    59    9    61    6    71    6    76    6
    //  hex:    0x 002F 000C  0036  0009  003B 0009  003D 0006  0047 0006  004C 0006
    //  seed type: 6          5           4          3          2          1
    uint256 private constant LIFESPAN_MATURATION_PERIOD = 0x002F000C00360009003B0009003D000600470006004C0006;

    // encoding to hex uint32(uint16+uint16) and pack into uint256
    //  dec:       1666 1428  1111  1005   905  833   758  692   586  531   493  408
    //  hex:    0x 0682 0594  0457  03ED  0389 0341  02F6 02B4  024A 0213  01ED 0198
    //  seed type: 6          5           4          3          2          1
    uint256 private constant MIN_MAX_YIELD_VALUE = 0x06820594045703ED0389034102F602B4024A021301ED0198;

    struct Planting {
        uint8 seedType;
        uint64 plantAt;
        uint64 maturationAt;
        uint64 wiltingAt;
        uint64 lastYieldAt;
        uint64 lastWateringAt;
        uint64 wateringDaysSkipped;
        uint64 yieldDaysSkipped;
        // bool wateringAloowed = now >= now > lastWatering + 1 day
        // lastWatering = now > lastWatering + 2 day ? 1 + (now - plantAt) / 1 day
        // bool yieldAloowed = now >= lastYield + 1day && Atnow > lastWatering && now <= lastWatering + 1 day
        // uint8 yieldCount;
        uint16 yieldBoost;
        // uint16 maturationBoost;
        // uint16 maturationProgress;
        uint256 appliedBoosts;
    }

    struct GlobalBoosterState {
        uint64 installAt;
        uint64 destroyAt;
    }

    struct LabState {
        GlobalBoosterState[] heaters;
        GlobalBoosterState[] waterings;
    }

    Item private _item;
    InnerCoin private _innerCoin;
    Plant private _plant;

    //plantId => State
    mapping(uint256 => Planting) private _plantings;

    // owner => global boosters
    mapping(address => mapping(uint8 => EnumerableSetUpgradeable.UintSet)) private _boosters;

    uint64 public baseInterval;

    function initialize(
        address itemAddress,
        address plantAddress,
        address innerCoinAddress,
        uint64 interval
    ) external initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, _msgSender());

        _setItem(itemAddress);
        _setPlant(plantAddress);
        _setInnerCoin(innerCoinAddress);

        _setBaseInterval(interval);
    }

    /**
     * @dev Get the market contract address
     */
    function getItemContract() external view returns (address) {
        return address(_item);
    }

    function getPlantContract() external view returns (address) {
        return address(_plant);
    }

    function setItemContract(address itemAddress) external {
        _checkRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setItem(itemAddress);
    }

    function setPlantContract(address plantAddress) external {
        _checkRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setPlant(plantAddress);
    }

    function setInnerCoinContract(address innerCoinAddress) external {
        _checkRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setInnerCoin(innerCoinAddress);
    }

    function setBaseInterval(uint64 interval) external {
        _checkRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setBaseInterval(interval);
    }

    function _setItem(address itemAddress) internal {
        if (itemAddress == address(0)) revert ZeroAddress();
        _item = Item(itemAddress);
    }

    function _setPlant(address plantAddress) internal {
        if (plantAddress == address(0)) revert ZeroAddress();
        _plant = Plant(plantAddress);
    }

    function _setInnerCoin(address innerCoinAddress) internal {
        if (innerCoinAddress == address(0)) revert ZeroAddress();
        _innerCoin = InnerCoin(innerCoinAddress);
    }

    function _setBaseInterval(uint64 interval) internal {
        if (interval == 0) revert ZeroValue();
        baseInterval = interval;
    }

    function getPlanting(uint256 plantId) external view returns (Planting memory planting) {
        planting = _plantings[plantId];
        if (planting.seedType == 0) revert NotExists();
    }

    function _extract32(uint256 packed, uint8 pos) internal pure returns (uint32) {
        return uint32(packed >> (pos * 32));
    }

    function _extract2x16(uint256 packed, uint8 pos) internal pure returns (uint16, uint16) {
        uint32 v = _extract32(packed, pos);
        return (uint16(v >> 16), uint16(v));
    }

    function _getSeedType(uint256 randomSeed) internal view returns (uint8 seedType) {
        uint256 raritytSum;
        // uint256 seedRarities = SEED_RARITIES;
        uint32 random = uint32(ShuffleId.diceRoll(1000, randomSeed));
        uint32 rarity;
        do {
            // rarity = uint32(seedRarities & 0xFFFFFFFF);
            rarity = _extract32(SEED_RARITIES, seedType);
            seedType++; // shift next type
            raritytSum += rarity;
            // seedRarities >>= 32;
            if (random <= raritytSum) {
                break;
            }
        } while (rarity > 0);
    }

    function _getBoostMask(uint8 itemId) internal pure returns (uint256) {
        // require(itemId > 0, "WRONG_BOOST_TYPE");
        return uint256(1) << (itemId - 1);
    }

    function _getMaturationBoost(uint256 itemId) internal pure returns (uint16) {
        if (itemId == ITEM_ID_FERTILIZER) {
            return 3000; // 30$
        } else if (itemId == ITEM_ID_AUTOWATERING) {
            return 2000; // 20$
        } else if (itemId == ITEM_ID_HEATING) {
            return 3000; // 30$
        }
        return 0;
    }

    function _getYieldBoost(uint256 itemId) internal pure returns (uint16) {
        if (itemId == ITEM_ID_SEED) {
            return 2000; // 20%
        } else if (itemId == ITEM_ID_BOX) {
            return 2500; // 25%
        } else if (itemId == ITEM_ID_FERTILIZER) {
            return 1500; // 15%
        } else if (itemId == ITEM_ID_AUTOWATERING) {
            return 2000; // 20%
        } else if (itemId == ITEM_ID_HEATING) {
            return 3000; // 30$
        }
        return 0;
    }

    function _getSeedCount(uint256 randomSeed) internal view returns (uint256) {
        uint32 random = uint32(ShuffleId.diceRoll(1000, randomSeed));
        if (random > 950) {
            return 5; //5%
        } else if (random > 850) {
            return 4; //10%
        } else if (random > 700) {
            return 3; //15%
        } else if (random > 500) {
            return 2; //20%
        } else if (random > 50) {
            return 1; //45%
        } else {
            return 0; //5%
        }
    }

    function _burnItem(address from, uint256 id) internal {
        _item.burnBatch(from, _asArr1(id), _asArr1(1));
    }

    function _burnItemMany(
        address from,
        uint256[] memory ids,
        uint256 amount
    ) internal {
        uint256[] memory amounts = _asArray(ids.length);
        for (uint256 i = 0; i < amounts.length; i++) {
            amounts[i] = amount;
        }
        _item.burnBatch(from, ids, amounts);
    }

    function _transferItem(
        address from,
        address to,
        uint256 id
    ) internal {
        _item.safeBatchTransferFrom(from, to, _asArr1(id), _asArr1(1), "");
    }

    function _transferItemMany(
        address from,
        address to,
        uint256[] memory ids
    ) internal {
        uint256[] memory amounts = _asArray(ids.length);
        for (uint256 i = 0; i < amounts.length; i++) {
            amounts[i] = 1;
        }
        _item.safeBatchTransferFrom(from, to, ids, amounts, "");
    }

    function seed() external {
        _seed(1);
    }

    // function seedFor(address to) external returns (uint256[] memory plantIds) {
    //   if (!hasRole(OPERATOR_ROLE, _msgSender())) revert NoOperatorRole();
    //   return _plantingBatch(to, 1);
    // }

    function seedBatch(uint256 count) external {
        _seed(count);
    }

    function _seed(uint256 count) internal returns (uint256[] memory plantIds) {
        _item.burnBatch(_msgSender(), _asArr2(ITEM_ID_SEED, ITEM_ID_POT), _asArr2(count, count));
        return _plantingBatch(_msgSender(), count);
    }

    function _plantingBatch(address to, uint256 count) internal returns (uint256[] memory plantIds) {
        plantIds = _plant.mintBatch(to, count);
        // plantId = _plant.mint(to);
        uint64 _now = uint64(block.timestamp);

        for (uint256 i = 0; i < plantIds.length; ++i) {
            uint8 seedType = _getSeedType(plantIds[i]);

            _plantings[plantIds[i]].plantAt = _now;
            _plantings[plantIds[i]].lastWateringAt = _now;
            _plantings[plantIds[i]].seedType = seedType;

            (uint16 lifespanDays, uint16 maturationDays) = _extract2x16(LIFESPAN_MATURATION_PERIOD, seedType);

            _plantings[plantIds[i]].maturationAt = _now + maturationDays * baseInterval;
            _plantings[plantIds[i]].wiltingAt = _now + lifespanDays * baseInterval;

            emit Seed(to, plantIds[i], seedType);
        }
    }

    error GlobalBoostNotAllowed();
    error OnlyLocalBoosterAllowed();
    error BoostAlreadyApplied();
    error BoostNotApplied();

    function boost(uint256 plantId, uint256[] memory itemIds) external {
        address owner = _plant.ownerOf(plantId);
        if (owner != _msgSender()) revert CallerIsNotOwner();

        Planting memory planting = _plantings[plantId];
        if (planting.seedType == 0) revert NotExists();

        for (uint256 i = 0; i < itemIds.length; i++) {
            uint256 mask = _getBoostMask(uint8(itemIds[i]));
            if (mask & planting.appliedBoosts != 0) revert BoostAlreadyApplied();

            if (itemIds[i] == ITEM_ID_FERTILIZER) {
                // burn one time boosters
                _burnItem(owner, itemIds[i]);
            } else if (itemIds[i] == ITEM_ID_LAMP || itemIds[i] == ITEM_ID_BOX) {
                // transfer to contract other boosters
                _transferItem(owner, address(this), itemIds[i]);
            } else {
                revert OnlyLocalBoosterAllowed();
            }
            // add booster per plant
            planting.appliedBoosts |= mask;

            planting = _addYieldBoost(planting, _getYieldBoost(itemIds[i]));
            planting = _speedupMaturationTime(planting, _getMaturationBoost(itemIds[i]), ~uint64(0));
        }
        _plantings[plantId] = planting;
    }

    function unboost(uint256 plantId, uint256[] memory itemIds) external {
        address owner = _plant.ownerOf(plantId);
        if (owner != _msgSender()) revert CallerIsNotOwner();

        Planting memory planting = _plantings[plantId];
        if (planting.seedType == 0) revert NotExists();

        for (uint256 i = 0; i < itemIds.length; i++) {
            if (itemIds[i] != ITEM_ID_LAMP && itemIds[i] != ITEM_ID_BOX) {
                revert OnlyLocalBoosterAllowed();
            }

            uint256 mask = _getBoostMask(uint8(itemIds[i]));
            if (mask & planting.appliedBoosts == 0) revert BoostNotApplied();

            // remove booster per plant
            planting.appliedBoosts ^= mask;

            // transfer from contract
            _transferItem(address(this), owner, itemIds[i]);

            planting = _removeYieldBoost(planting, _getYieldBoost(itemIds[i]));
            planting = _slowdownMaturationTime(planting, _getMaturationBoost(itemIds[i]), ~uint64(0));
        }
        _plantings[plantId] = planting;
    }

    function _addYieldBoost(Planting memory planting, uint16 yieldBoost) internal pure returns (Planting memory) {
        planting.yieldBoost = uint16(_pcnt(10000 + planting.yieldBoost, 10000 + yieldBoost, 10000) - 10000);
        return planting;
    }

    function _removeYieldBoost(Planting memory planting, uint16 yieldBoost) internal pure returns (Planting memory) {
        planting.yieldBoost = uint16(_pcnt(10000 + planting.yieldBoost, 10000, 10000 + yieldBoost) - 10000);
        return planting;
    }

    function _speedupMaturationTime(
        Planting memory planting,
        uint16 maturationBoost,
        uint64 destroyAt
    ) internal view returns (Planting memory) {
        uint64 _now = uint64(block.timestamp);
        if (_now < planting.maturationAt && _now < destroyAt) {
            planting.maturationAt -= uint64(_pcnt((destroyAt < planting.maturationAt ? destroyAt : planting.maturationAt) - _now, maturationBoost, 10000));
        }
        return planting;
    }

    function _slowdownMaturationTime(
        Planting memory planting,
        uint16 maturationBoost,
        uint64 destroyAt
    ) internal view returns (Planting memory) {
        uint64 _now = uint64(block.timestamp);
        if (_now < planting.maturationAt && _now < destroyAt) {
            planting.maturationAt += uint64(
                _pcnt((destroyAt < planting.maturationAt ? destroyAt : planting.maturationAt) - _now, maturationBoost, 10000 - maturationBoost)
            );
        }
        return planting;
    }

    // function _applyGlobalBoosts(uint256[] memory itemIds) internal {
    //   // _plantings[plantId].profitBoost += profitBoost;
    //   // _plantings[plantId].maturationBoost += maturationBoost;
    //   // emit Boost(owner, plantId, profitBoost, maturationBoost);
    //   uint256[] memory platIds = _tokensOfOwner(_msgSender());
    //   Planting memory planting;
    //   for (uint256 i = 0; i < itemIds.length; i++) {
    //     uint256 mask = _getBoostMask(uint8(itemIds[i]));
    //     if (mask & BOOST_MASK_WATERING != 0 || mask & BOOST_MASK_HEATER != 0) {
    //       // add heater/watering
    //       for (uint256 j = 0; j < platIds.length; j++) {
    //         planting = _plantings[platIds[j]];
    //         if (mask & planting.appliedBoosts == 0) {
    //           _plantings[platIds[j]].appliedBoosts |= mask;
    //           if (uint64(block.timestamp) < _plantings[platIds[j]].maturationAt) {
    //             _plantings[platIds[j]].maturationAt -= uint64(
    //               _pcnt(_plantings[platIds[j]].maturationAt - uint64(block.timestamp), _getMaturationBoost(itemIds[i]), 10000)
    //             );
    //           }
    //           _plantings[platIds[j]].yieldBoost += _getYieldBoost(itemIds[i]);
    //         }
    //       }
    //     }
    //   }
    // }

    function isWateringAllowed(uint256 plantId) external view returns (bool) {
        Planting memory planting = _plantings[plantId];
        if (planting.seedType == 0) return false;
        // (uint16 lifespanDays, ) = _extract2x16(LIFESPAN_MATURATION_PERIOD, planting.seedType);
        // uint64 wiltingAt = planting.plantAt + lifespanDays * baseInterval;
        uint64 _now = uint64(block.timestamp);

        //todo: check autowatering
        uint64 daysSinceLastWatering = (_now - planting.lastWateringAt) / baseInterval;
        if (_now < planting.wiltingAt && daysSinceLastWatering > 0) return true;
        return false;
    }

    function isHarwestAllowed(uint256 plantId) external view returns (bool) {
        Planting memory planting = _plantings[plantId];
        if (planting.seedType == 0) return false;
        uint64 _now = uint64(block.timestamp);
        uint64 daysSinceLastYield = (_now - planting.lastYieldAt) / baseInterval;
        uint64 daysSinceLastWatering = (_now - planting.lastWateringAt) / baseInterval;
        // (uint16 lifespanDays, ) = _extract2x16(LIFESPAN_MATURATION_PERIOD, planting.seedType);
        // bool isWilted = _now >= planting.plantAt + lifespanDays * baseInterval;
        bool isWilted = _now >= planting.wiltingAt;
        if (
            _now >= planting.maturationAt &&
            daysSinceLastYield > 0 &&
            (daysSinceLastWatering == 1 || (daysSinceLastWatering == 0 && planting.wateringDaysSkipped == 0) || isWilted)
        ) return true;

        return false;
    }

    error YieldNotReady();
    error PlantingHasWithered();
    error WateringMissed();
    error AlreadyWatered();
    error StillMaturation();

    function _watering(uint256 plantId) internal {
        address owner = _plant.ownerOf(plantId);
        if (owner != _msgSender()) revert CallerIsNotOwner();

        Planting memory planting = _plantings[plantId];
        if (planting.seedType == 0) revert NotExists();

        // (uint16 lifespanDays, ) = _extract2x16(LIFESPAN_MATURATION_PERIOD, planting.seedType);
        // uint64 wiltingAt = planting.plantAt + lifespanDays * baseInterval;

        uint64 _now = uint64(block.timestamp);
        if (_now >= planting.wiltingAt) revert PlantingHasWithered();

        //todo: check autowatering
        uint64 daysSinceLastWatering = (_now - planting.lastWateringAt) / baseInterval;
        if (daysSinceLastWatering == 0) revert AlreadyWatered();

        if (daysSinceLastWatering > 1 && planting.lastWateringAt < planting.maturationAt - baseInterval) {
            uint64 maturationNoWaterPeriod = planting.maturationAt - planting.lastWateringAt - baseInterval;
            planting.maturationAt = planting.lastWateringAt + daysSinceLastWatering * baseInterval + maturationNoWaterPeriod;
        }

        planting.wateringDaysSkipped = daysSinceLastWatering - 1;
        planting.lastWateringAt += daysSinceLastWatering * baseInterval;

        if (planting.maturationAt > planting.wiltingAt) {
            planting.maturationAt = planting.wiltingAt;
        }
        _plantings[plantId] = planting;
    }

    function _yieldOrRecycle(uint256 plantId, bool isRecycle) internal {
        address owner = _plant.ownerOf(plantId);
        if (owner != _msgSender()) revert CallerIsNotOwner();

        Planting memory planting = _plantings[plantId];
        if (planting.seedType == 0) revert NotExists();

        uint64 _now = uint64(block.timestamp);
        if (_now < planting.maturationAt) revert StillMaturation();

        uint64 daysSinceLastYield = (_now - planting.lastYieldAt) / baseInterval;
        if (daysSinceLastYield == 0) revert YieldNotReady();

        uint64 daysSinceLastWatering = (_now - planting.lastWateringAt) / baseInterval;
        // (uint16 lifespanDays, ) = _extract2x16(LIFESPAN_MATURATION_PERIOD, planting.seedType);
        // bool isWilted = _now >= planting.plantAt + lifespanDays * baseInterval;
        bool isWilted = _now >= planting.wiltingAt;
        bool isMaturated = (planting.lastWateringAt + baseInterval >= planting.maturationAt);

        if ((daysSinceLastWatering > 1 || (daysSinceLastWatering == 0 && planting.wateringDaysSkipped > 0)) && !isWilted) revert WateringMissed();
        // require(daysSinceLastWatering == 1 || (daysSinceLastWatering == 0 && planting.wateringDaysSkipped == 0) || isWilted, WATERING_MISSED);

        if (isMaturated) {
            if (isRecycle || (isWilted && daysSinceLastWatering > 1)) {
                // extract seeds
                uint256 seedCount = _getSeedCount(plantId);
                if (seedCount > 0) {
                    _item.mint(owner, ITEM_ID_SEED, seedCount);
                }
                emit Recycle(owner, plantId, seedCount);

                isWilted = true;
            } else {
                _plantings[plantId].yieldDaysSkipped = daysSinceLastYield;
                _plantings[plantId].lastYieldAt = planting.lastYieldAt + daysSinceLastYield * baseInterval;
                // allowing last yield
                uint256 amount = _pcnt(uint256(_getRandomYield(planting.seedType, plantId)) * 1 ether, 10000 + planting.yieldBoost, 10000);
                _innerCoin.mint(owner, amount);
                emit Harvest(owner, plantId, amount);
            }
        }
        if (isWilted) {
            // return boosters
            if (planting.appliedBoosts & BOOST_MASK_LAMP != 0) {
                _transferItem(address(this), owner, ITEM_ID_LAMP);
            }
            if (planting.appliedBoosts & BOOST_MASK_BOX != 0) {
                _transferItem(address(this), owner, ITEM_ID_BOX);
            }
            _plant.burn(plantId);
        }
    }

    function _pcnt(
        uint256 value,
        uint256 pcnt,
        uint256 base
    ) internal pure returns (uint256) {
        return (value * pcnt) / base;
    }

    function _getRandomYield(uint8 seedType, uint256 randomSeed) internal view returns (uint16) {
        (uint16 maxYield, uint16 minYield) = _extract2x16(MIN_MAX_YIELD_VALUE, seedType);
        return minYield + uint16(ShuffleId.diceRoll(maxYield - minYield, randomSeed));
    }

    function yieldAndWatering(uint256 plantId) external {
        _watering(plantId);
        _yieldOrRecycle(plantId, false);
    }

    function watering(uint256 plantId) external {
        _watering(plantId);
    }

    function harvest(uint256 plantId) external {
        _yieldOrRecycle(plantId, false);
    }

    function recycling(uint256 plantId) external {
        _yieldOrRecycle(plantId, true);
    }

    function _asArr1(uint256 x1) private pure returns (uint256[] memory arr) {
        arr = _asArray(1);
        arr[0] = x1;
    }

    function _asArr2(uint256 x1, uint256 x2) private pure returns (uint256[] memory arr) {
        arr = _asArray(2);
        arr[0] = x1;
        arr[1] = x2;
    }

    function _asArray(uint256 length) private pure returns (uint256[] memory) {
        return new uint256[](length);
    }

    // function _asSingletonBundle(uint256 id, uint256 amount) private pure returns (AmountStore.Bundle memory bundle) {
    //   bundle = AmountStore.bandleCreate(1);
    //   bundle.ids[0] = id;
    //   bundle.amounts[0] = amount;
    // }

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
        _checkRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }
}
