// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "./lib/ERC721EnumerableUpgradeableMod.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "./NFT.sol";
import "./lib/errors.sol";
import "./lib/ShuffleId.sol";

/**
 * @dev {ERC721} base card template
 */
contract Card is
  Initializable,
  AccessControlEnumerableUpgradeable,
  UUPSUpgradeable,
  PausableUpgradeable,
  ERC721EnumerableUpgradeableMod,
  ERC721URIStorageUpgradeable
{
  using ShuffleId for ShuffleId.IdMatrix;

  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
  bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

  uint256 internal constant MAX_LEVEL = 4;
  uint256 internal constant MAX_AMOUNT_PER_LEVEL = 2500;
  uint256 internal constant MAX_AMOUNT_TOTAL = 10000;
  //[6499, 3000, 480, 20]

  error MaxUsesCountReached();
  error MaxOwnsCountReached();
  error ZeroUseCount();

  event Used(uint256 tokenId, uint256 remainUses);

  struct CardMeta {
    uint128 uses;
    uint128 level;
  }

  string private _baseTokenURI;
  uint256 private _tokenIdTracker;
  uint128 private _maxOwnsCount;
  uint128 private _maxUsesCount;
  // Mapping from token ID to token meta
  mapping(uint256 => CardMeta) private _meta;
  // level id = levelUri
  mapping(uint128 => string) private _levelURIs;

  NFT private _nft;
  bool public claimEnabled;
  mapping(uint128 => ShuffleId.IdMatrix) private _claimMatrix;

  function initialize(
    string memory name,
    string memory symbol,
    string memory baseTokenURI,
    uint128 ownsCount,
    uint128 usesCount
  ) external initializer onlyProxy {
    __Card_init(name, symbol, baseTokenURI, ownsCount, usesCount);
  }

  function __Card_init(
    string memory name,
    string memory symbol,
    string memory baseTokenURI,
    uint128 ownsCount,
    uint128 usesCount
  ) internal onlyInitializing {
    __Pausable_init_unchained();
    __ERC721_init_unchained(name, symbol);
    __Card_init_unchained(baseTokenURI, ownsCount, usesCount);
  }

  function __Card_init_unchained(
    string memory baseTokenURI,
    uint128 ownsCount,
    uint128 usesCount
  ) internal onlyInitializing {
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    _setupRole(MINTER_ROLE, _msgSender());
    _setupRole(OPERATOR_ROLE, _msgSender());

    _baseTokenURI = baseTokenURI;
    _maxOwnsCount = ownsCount;
    _maxUsesCount = usesCount;
  }

  /**
   * @dev See {IERC721Metadata-tokenURI}.
   */
  function tokenURI(uint256 tokenId) public view virtual override(ERC721URIStorageUpgradeable, ERC721Upgradeable) returns (string memory) {
    string memory _levelURI = _levelURIs[_meta[tokenId].level];
    if (bytes(_levelURI).length == 0) {
      return super.tokenURI(tokenId);
    }

    if (bytes(_baseTokenURI).length == 0) {
      return _levelURI;
    }

    return string(abi.encodePacked(_baseTokenURI, _levelURI));
  }

  /**
   * @dev See {ERC721-_baseURI}.
   */
  function _baseURI() internal view override returns (string memory) {
    return _baseTokenURI;
  }

  /**
   * @dev Return base token URI
   */
  function baseURI() external view returns (string memory) {
    return _baseURI();
  }

  /**
   * @dev Set new base URI. See {ERC721-_baseURI}.
   */
  function setBaseURI(string memory baseTokenURI) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _baseTokenURI = baseTokenURI;
  }

  function getLevelURI(uint128 levelId) external view returns (string memory) {
    return _levelURIs[levelId];
  }

  function setLevelURI(uint128 levelId, string memory levelURI) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _levelURIs[levelId] = levelURI;
  }

  function setLevelURIs(uint128[] memory levelIds, string[] memory levelURIs) external onlyRole(DEFAULT_ADMIN_ROLE) {
    if (levelIds.length == 0 || levelIds.length != levelURIs.length) revert WrongInputParams();
    for (uint256 i = 0; i < levelIds.length; i++) {
      _levelURIs[levelIds[i]] = levelURIs[i];
    }
  }

  /**
   * @dev Get max owns count.
   */
  function maxOwns() external view returns (uint256) {
    return _maxOwnsCount;
  }

  /**
   * @dev Get max uses count.
   */
  function maxUses() external view returns (uint256) {
    return _maxUsesCount;
  }

  function __mint(address to, uint128 level) private {
    _mint(to, _tokenIdTracker);
    _meta[_tokenIdTracker].level = level;
    _tokenIdTracker++;
  }

  function __mintBatch(
    address to,
    uint128 level,
    uint256 amount
  ) private {
    while (amount > 0) {
      __mint(to, level);
      amount--;
    }
  }

  /**
   * @dev Creates a new token with default uri
   */
  function mint(address to, uint128 level) external onlyRole(MINTER_ROLE) {
    __mint(to, level);
  }

  /**
   * @dev Creates a batch of new tokens with default uri
   */
  function mintBatch(
    address to,
    uint128 level,
    uint256 amount
  ) external onlyRole(MINTER_ROLE) {
    __mintBatch(to, level, amount);
  }

  function mintMultiBatch(
    address[] memory tos,
    uint128[] memory levels,
    uint256[] memory amounts
  ) external onlyRole(MINTER_ROLE) {
    if (tos.length != levels.length) revert WrongInputParams();
    if (tos.length != amounts.length) revert WrongInputParams();
    for (uint256 i = 0; i < tos.length; i++) {
      __mintBatch(tos[i], levels[i], amounts[i]);
    }
  }

  function _burn(uint256 tokenId) internal override(ERC721URIStorageUpgradeable, ERC721Upgradeable) {
    super._burn(tokenId);
    // clean state
    delete _meta[tokenId];
  }

  function __burn(uint256 tokenId) internal {
    if (!_isApprovedOrOwner(_msgSender(), tokenId)) revert CallerIsNotOwnerNorApproved();
    _burn(tokenId);
  }

  /**
   * @dev Destroys `tokenId`. See {ERC721-_burn}.
   */
  function burn(uint256 tokenId) external {
    __burn(tokenId);
  }

  function burnBatch(uint256[] memory tokenIds) external {
    for (uint256 i = 0; i < tokenIds.length; i++) {
      __burn(tokenIds[i]);
    }
  }

  function burnFrom(address owner, uint256 amount) external {
    uint256[] memory cardIds = tokensOfOwner(owner);
    require(cardIds.length > 0, "NOTHING_TO_CLAIM");
    if (amount > cardIds.length || amount == 0) {
      amount = cardIds.length;
    }
    for (uint256 i = 0; i < amount; i++) {
      __burn(cardIds[i]);
    }
  }

  /**
   * @dev Batch transfer
   */
  function transferFromBatch(
    address from,
    address to,
    uint256[] memory tokenIds
  ) external virtual {
    for (uint256 i = 0; i < tokenIds.length; i++) {
      transferFrom(from, to, tokenIds[i]);
    }
  }

  function burnUsed(uint256 amount, uint256 offset) external virtual {
    uint256[] memory tokenIds = allTokens();
    require(amount > 0 && offset + amount <= tokenIds.length, "OUT_OF_BOUNDS");
    uint256 tokenId;
    uint256 burnAmount;
    for (uint256 i = 0; i < amount; i++) {
      tokenId = tokenIds[offset + i];
      if (_meta[tokenId].uses > 0) {
        _burn(tokenId);
        burnAmount++;
      }
    }
    require(burnAmount > 0, "NOTHING_TO_BURN");
  }

  function usedTokens() external view returns (uint256[] memory usedTokenIds) {
    uint256[] memory tokenIds = allTokens();
    usedTokenIds = new uint256[](tokenIds.length);
    uint256 usedAmount;
    for (uint256 i = 0; i < tokenIds.length; i++) {
      if (_meta[tokenIds[i]].uses > 0) {
        usedTokenIds[usedAmount++] = tokenIds[i];
      }
    }
    // shrink array
    if (usedAmount < tokenIds.length) {
      uint256 trim = tokenIds.length - usedAmount;
      assembly {
        mstore(usedTokenIds, sub(mload(usedTokenIds), trim))
      }
    }
  }

  /**
   * @dev Increment uses count for card with specified ID.
   */
  function useCard(uint256 tokenId, uint128 count) external onlyRole(OPERATOR_ROLE) returns (CardMeta memory meta) {
    if (!_exists(tokenId)) revert NotExists();
    if (count == 0) revert ZeroUseCount();
    meta = _meta[tokenId];
    // require(meta.uses + count <= _maxUsesCount, "MAX_USES_COUNT_REACHED");
    if (meta.uses + count > _maxUsesCount) revert MaxUsesCountReached();
    meta.uses += count;
    //save uses count
    _meta[tokenId].uses = meta.uses;
    emit Used(tokenId, _maxUsesCount - meta.uses);
    return meta;
  }

  /**
   * @dev Increment uses count for card for specific owner.
   */
  function useCardFrom(address owner, uint128 count)
    external
    onlyRole(OPERATOR_ROLE)
    returns (
      uint256 tokenId,
      CardMeta memory meta,
      uint128 maxUsesCount
    )
  {
    if (count == 0) revert ZeroUseCount();
    uint256 cardsCount = balanceOf(owner);
    if (cardsCount == 0) revert NotExists();
    maxUsesCount = _maxUsesCount;
    for (uint256 i = 0; i < cardsCount; i++) {
      tokenId = tokenOfOwnerByIndex(owner, i);
      meta = _meta[tokenId];
      if (meta.uses + count <= maxUsesCount) {
        meta.uses += count;
        //save uses count
        _meta[tokenId].uses = meta.uses;
        emit Used(tokenId, _maxUsesCount - meta.uses);
        return (tokenId, meta, maxUsesCount);
        // break;
      }
    }
    revert MaxUsesCountReached();
  }

  /**
   * @dev Get card uses count
   */
  function cardUses(uint256 tokenId) external view returns (uint128) {
    if (!_exists(tokenId)) revert NotExists();
    return _meta[tokenId].uses;
  }

  function cardUsesOf(address owner) external view returns (uint128 uses) {
    uint256 cardsCount = balanceOf(owner);
    if (cardsCount == 0) revert NotExists();
    for (uint256 i = 0; i < cardsCount; i++) {
      uint256 tokenId = tokenOfOwnerByIndex(owner, i);
      uses += _meta[tokenId].uses;
    }
  }

  function canUseCardFrom(address owner, uint128 count) external view returns (bool) {
    if (count == 0) revert ZeroUseCount();
    uint256 cardsCount = balanceOf(owner);
    if (cardsCount == 0) revert NotExists();
    uint256 tokenId;
    CardMeta memory meta;
    for (uint256 i = 0; i < cardsCount; i++) {
      tokenId = tokenOfOwnerByIndex(owner, i);
      meta = _meta[tokenId];
      if (meta.uses + count <= _maxUsesCount) {
        return true;
      }
    }
    return false;
  }

  /**
   * @dev Get card level
   */
  function cardLevel(uint256 tokenId) external view returns (uint128) {
    if (!_exists(tokenId)) revert NotExists();
    return _meta[tokenId].level;
  }

  /**
   * @dev See {IERC721-isApprovedForAll}.
   */
  function isApprovedForAll(address owner, address operator) public view virtual override(IERC721Upgradeable, ERC721Upgradeable) returns (bool) {
    return hasRole(OPERATOR_ROLE, operator) || super.isApprovedForAll(owner, operator);
  }

  /**
   * @dev Pauses/Unpauses all token transfers.
   */
  function togglePause() external onlyRole(DEFAULT_ADMIN_ROLE) {
    if (paused()) {
      _unpause();
    } else {
      _pause();
    }
  }

  function setNFT(address nftAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
    if (nftAddress == address(0)) revert ZeroAddress();
    _nft = NFT(nftAddress);
  }

  function getNFT() external view returns (address) {
    return address(_nft);
  }

  function _getRandomId(uint128 level) internal returns (uint256 index) {
    // Gold (level 4): рандомный персонаж типа Boss рандомной фракции
    // RU BOSS 626-1250
    // JP BOSS 3126-3750
    // AF BOSS 5626-6250
    // IT BOSS 8126-8750
    // Silver  (level 3): рандомный персонаж типа Fighter рандомной фракции
    // RU FIGHTER 1251-1875
    // JP FIGHTER 3751-4375
    // AF FIGHTER 6251-6875
    // IT FIGHTER 8751-9375
    // Bronze  (level 2): рандомный персонаж типа Seller рандомной фракции
    // RU SELLER 1876-2500
    // JP SELLER 4376-5000
    // AF SELLER 6876-7500
    // IT SELLER 9376-10000
    // Common  (level 1): рандомный персонаж типа Grover рандомной фракции
    // RU GROWER 1-625
    // JP GROWER 2501-3125
    // AF GROWER 5001-5625
    // IT GROWER 7501-8125
    // uint256[][] memory startIdxs = [[1, 2501, 5001, 7501], [1876, 4376, 6876, 9376], [1251, 3751, 6251, 8751], [626, 3126, 5626, 8126]];

    // start index
    if (level == 2) {
      // bronze
      index = 1876;
    } else if (level == 3) {
      // silver
      index = 1251;
    } else if (level == 4) {
      // gold
      index = 626;
    } else {
      index = 1;
    }

    uint256 random = _claimMatrix[level].next();
    index += (random % 625) + (random / 625) * 2500;
  }

  function _getProbabilies() internal pure returns (uint256[] memory probabilies) {
    probabilies = new uint256[](4);
    probabilies[0] = 6370;
    probabilies[1] = 2950;
    probabilies[2] = 486;
    probabilies[3] = 194;
  }

  function _getRemainAmount(uint128 level) internal view returns (uint256) {
    return _claimMatrix[level].max() - _claimMatrix[level].count();
  }

  function _getRemainAmounts() internal view returns (uint256[] memory amounts) {
    amounts = new uint256[](4);
    amounts[0] = _getRemainAmount(1);
    amounts[1] = _getRemainAmount(2);
    amounts[2] = _getRemainAmount(3);
    amounts[3] = _getRemainAmount(4);
  }

  function _correctLevelRemainAmount(uint256 i) internal view returns (uint128) {
    uint256[] memory remainAmounts = _getRemainAmounts();

    // if finded random index has no more supply
    if (remainAmounts[i] == 0) {
      // find first avail amount of possible lowest level
      for (uint256 k = 0; k < MAX_LEVEL; k++) {
        if (k != i && remainAmounts[k] > 0) {
          return uint128(k + 1);
          // break;
        }
      }
    } else {
      return uint128(i + 1);
    }
    return 0;
  }

  function _getRandomLevel(uint256 seed) internal view returns (uint128) {
    uint256[] memory probabilities = _getProbabilies();
    uint256 i;
    uint256 probabilitySum = 0;
    uint256 random = ShuffleId.diceRoll(MAX_AMOUNT_TOTAL + 1, seed);
    for (i = 0; i < MAX_LEVEL; i++) {
      probabilitySum += probabilities[i];
      if (random < probabilitySum) {
        break;
      }
    }

    return _correctLevelRemainAmount(i);
  }

  function initClaim(address nftAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
    if (nftAddress == address(0)) revert ZeroAddress();
    _nft = NFT(nftAddress);
    // level 1 - Common
    // level 2 - Bronze
    // level 3 - Silver
    // level 4 - Gold
    _claimMatrix[1].setMax(MAX_AMOUNT_PER_LEVEL);
    _claimMatrix[2].setMax(MAX_AMOUNT_PER_LEVEL);
    _claimMatrix[3].setMax(MAX_AMOUNT_PER_LEVEL);
    _claimMatrix[4].setMax(MAX_AMOUNT_PER_LEVEL);
    claimEnabled = true;
  }

  function toggleClaimEnabled() external onlyRole(DEFAULT_ADMIN_ROLE) {
    claimEnabled = !claimEnabled;
  }

  function _claim(address owner, uint256 amount) internal {
    require(claimEnabled, "CLAIM_DISABLED");
    require(address(_nft) != address(0), "WRONG_PARAMS");
    uint256[] memory cardIds = tokensOfOwner(owner);
    require(cardIds.length > 0, "NOTHING_TO_CLAIM");
    if (amount > cardIds.length || amount == 0) {
      amount = cardIds.length;
    }
    uint256[] memory nftIds = new uint256[](amount);
    uint256 claimAmount;
    Card.CardMeta memory meta;
    for (uint256 i = 0; i < amount; i++) {
      meta = _meta[cardIds[i]];
      if (meta.uses == 0) {
        nftIds[claimAmount++] = _getRandomId(meta.level);
      }
      _burn(cardIds[i]);
    }

    require(claimAmount > 0, "NOTHING_TO_CLAIM");
    // shrink array
    if (claimAmount < amount) {
      uint256 trim = amount - claimAmount;
      assembly {
        mstore(nftIds, sub(mload(nftIds), trim))
      }
    }
    if (claimAmount > 1) {
      _nft.mintBatch(owner, nftIds);
    } else {
      _nft.mint(owner, nftIds[0]);
    }
  }

  function claimExternal(address owner) external onlyRole(OPERATOR_ROLE) returns (uint256 tokenId) {
    uint128 level = _getRandomLevel(uint160(owner));
    require(level != 0, "NO_MORE_AVALIABLE");
    tokenId = _getRandomId(level);
    _nft.mint(owner, tokenId);
  }

  function mintExternal(address to, uint128 level) external onlyRole(OPERATOR_ROLE) returns (uint256 tokenId) {
    require(level > 0 && level <= MAX_LEVEL, "WRONG_LEVEL");
    require(level == _correctLevelRemainAmount(level - 1), "NO_MORE_AVALIABLE");
    tokenId = _getRandomId(level);
    _nft.mint(to, tokenId);
  }

  function claim() external {
    _claim(_msgSender(), 10);
  }

  function claimN(uint256 amount) external {
    _claim(_msgSender(), amount);
  }

  function claimTo(address owner) external {
    _claim(owner, 10);
  }

  function claimTo(address owner, uint256 amount) external {
    _claim(owner, amount);
  }

  function claimStatus(uint128 level) external view returns (uint256, uint256) {
    return (_claimMatrix[level]._count, _claimMatrix[level]._max);
  }

  function claimStatusRange(uint128 levelFrom, uint128 levelTo) external view returns (uint256[] memory claimedAmounts, uint256[] memory maxAmounts) {
    if (levelFrom > levelTo) {
      (levelFrom, levelTo) = (levelTo, levelFrom);
    }
    uint256 len = levelTo - levelFrom + 1;
    claimedAmounts = new uint256[](len);
    maxAmounts = new uint256[](len);
    for (uint128 i = 0; i < len; i++) {
      claimedAmounts[i] = _claimMatrix[levelFrom + i]._count;
      maxAmounts[i] = _claimMatrix[levelFrom + i]._max;
    }
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal virtual override(ERC721EnumerableUpgradeableMod, ERC721Upgradeable) {
    super._beforeTokenTransfer(from, to, tokenId);
    if (paused()) revert TransferWhilePaused();
  }

  /**
   * @dev See {IERC165-supportsInterface}.
   */
  function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(AccessControlEnumerableUpgradeable, ERC721EnumerableUpgradeableMod, ERC721Upgradeable)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }

  /**
   * @dev See {UUPS-_authorizeUpgrade}. Allows `DEFAULT_ADMIN_ROLE` to perform upgrade.
   */
  function _authorizeUpgrade(address) internal override(UUPSUpgradeable) onlyRole(DEFAULT_ADMIN_ROLE) {}
}
