// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";

/**
 * @dev IItem
 */
interface IItem is IERC1155Upgradeable {
    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Creates `amount` new tokens for `to`, of token type `id`.
     *
     * See {ERC1155-_mint}.
     */
    function mint(
        address to,
        uint256 id,
        uint256 amount
    ) external;

    /**
     * @dev Batched version of {mint}
     */
    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts
    ) external;

    function burn(
        address account,
        uint256 id,
        uint256 value
    ) external;

    function burnBatch(
        address account,
        uint256[] memory ids,
        uint256[] memory values
    ) external;
}
