// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "./BaseERC721.sol";

/**
 * @dev {ERC721} NFT
 */
contract NFT is BaseERC721 {
  uint256 constant MAX_SUPPLY = 4420;

  function initialize(
    string memory name_,
    string memory symbol_,
    string memory baseURI_,
    string memory prefix,
    string memory postfix
  ) external initializer onlyProxy {
    __BaseERC721_init(name_, symbol_, baseURI_, prefix, postfix);
  }

  /**
   * @dev Creates a new token
   */
  function mint(address to, uint256 tokenId) external {
    _checkRole(MINTER_ROLE);
    require(totalSupply() <= MAX_SUPPLY, "ERC721: max supply reached");
    _mint(to, tokenId);
  }

  /**
   * @dev Creates a batch of new tokens
   */
  function mintBatch(address to, uint256[] memory tokenIds) external {
    _checkRole(MINTER_ROLE);
    require(totalSupply() <= MAX_SUPPLY, "ERC721: max supply reached");
    for (uint256 i = 0; i < tokenIds.length; i++) {
      _mint(to, tokenIds[i]);
    }
  }
}
