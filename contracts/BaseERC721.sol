// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./lib/ERC721.sol";

/**
 * @dev {BaseERC721} BaseERC721
 */
contract BaseERC721 is AccessControlEnumerableUpgradeable, UUPSUpgradeable, ERC721 {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    function __BaseERC721_init(
        string memory name_,
        string memory symbol_,
        string memory baseURI_,
        string memory prefix,
        string memory postfix
    ) internal onlyInitializing {
        __ERC721_init_unchained(name_, symbol_, baseURI_, prefix, postfix);
        __BaseERC721_init_unchained();
    }

    function __BaseERC721_init_unchained() internal onlyInitializing {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function setBaseURI(string memory baseTokenURI) external {
        _checkRole(DEFAULT_ADMIN_ROLE);
        _setBaseURI(baseTokenURI);
    }

    function setTokenURI(uint256 tokenId, string memory uri) external {
        _checkRole(DEFAULT_ADMIN_ROLE);
        _setTokenURI(tokenId, uri);
    }

    /**
     * @dev Destroys `tokenId`. See {ERC721-_burn}.
     */
    function burn(uint256 tokenId) external virtual {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not owner nor approved");
        _burn(tokenId);
    }

    /**
     * @dev Batch transfer
     */
    function transferFromBatch(
        address from,
        address to,
        uint256[] memory tokenIds
    ) external virtual {
        for (uint256 i = 0; i < tokenIds.length; ++i) {
            transferFrom(from, to, tokenIds[i]);
        }
    }

    /**
     * @dev See {IERC1155-isApprovedForAll}. Approve `OPERATOR_ROLE` for all tokens.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return hasRole(OPERATOR_ROLE, operator) || super.isApprovedForAll(owner, operator);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControlEnumerableUpgradeable, ERC721) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {UUPS-_authorizeUpgrade}. Allows `DEFAULT_ADMIN_ROLE` to perform upgrade.
     */
    function _authorizeUpgrade(address) internal virtual override(UUPSUpgradeable) {
        _checkRole(DEFAULT_ADMIN_ROLE);
    }
}
