// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "./BaseERC1155.sol";

/**
 * @dev {ERC721} Shop
 */
contract Item is BaseERC1155 {

  function initialize(
    string memory name_,
    string memory symbol_,
    string memory baseURI_,
    string memory prefix,
    string memory postfix
  ) external initializer {
    __BaseERC1155_init(name_, symbol_, baseURI_, prefix, postfix);
  }

  /**
   * @dev Creates `amount` new tokens for `to`, of token type `id`.
   *
   * See {ERC1155-_mint}.
   *
   * Requirements:
   *
   * - the caller must have the `MINTER_ROLE`.
   */
  function mint(
    address to,
    uint256 id,
    uint256 amount
  ) public virtual {
    _checkRole(MINTER_ROLE);
    _mint(to, id, amount, "");
  }

  /**
   * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] variant of {mint}.
   */
  function mintBatch(
    address to,
    uint256[] memory ids,
    uint256[] memory amounts
  ) public virtual {
    _checkRole(MINTER_ROLE);

    _mintBatch(to, ids, amounts, "");
  }
}
