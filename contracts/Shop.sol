// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "./BaseERC721.sol";

/**
 * @dev {ERC721} Shop
 */
contract Shop is BaseERC721 {
  uint256 private _tokenIdTracker;

  function initialize(
    string memory name_,
    string memory symbol_,
    string memory baseURI_,
    string memory prefix,
    string memory postfix
  ) external initializer {
    __BaseERC721_init(name_, symbol_, baseURI_, prefix, postfix);
  }

  function __mint(address to) internal returns (uint256 tokenId) {
    tokenId = ++_tokenIdTracker;
    _mint(to, tokenId);
  }

  /**
   * @dev Creates a new token with default uri
   */
  function mint(address to) external returns (uint256 tokenId) {
    _checkRole(MINTER_ROLE);
    return __mint(to);
  }

  /**
   * @dev Creates a batch of new tokens with default uri
   */
  function mintBatch(address to, uint256 amount) external returns (uint256[] memory tokenIds) {
    _checkRole(MINTER_ROLE);
    tokenIds = new uint256[](amount);
    for (uint256 i = 0; i < amount; ++i) {
      tokenIds[i] = __mint(to);
    }
  }
}
