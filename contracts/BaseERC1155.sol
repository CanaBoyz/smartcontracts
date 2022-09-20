// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./lib/ERC1155.sol";

/**
 * @dev {BaseERC1155} BaseERC1155
 */
contract BaseERC1155 is AccessControlEnumerableUpgradeable, UUPSUpgradeable, ERC1155 {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    function __BaseERC1155_init(
        string memory name_,
        string memory symbol_,
        string memory baseURI_,
        string memory prefix,
        string memory postfix
    ) internal onlyInitializing {
        __ERC1155_init_unchained(name_, symbol_, baseURI_, prefix, postfix);
        __BaseERC1155_init_unchained();
    }

    function __BaseERC1155_init_unchained() internal onlyInitializing {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function setBaseURI(string memory baseTokenURI) external {
        _checkRole(DEFAULT_ADMIN_ROLE);
        _setBaseURI(baseTokenURI);
    }

    function setTokenURI(uint256 id, string memory newURI) external {
        _checkRole(DEFAULT_ADMIN_ROLE);
        _setTokenURI(id, newURI);
    }

    function setURISubPrePost(string memory prefix, string memory postfix) external {
        _checkRole(DEFAULT_ADMIN_ROLE);
        _setURISubPrePost(prefix, postfix);
    }

    function burn(
        address account,
        uint256 id,
        uint256 value
    ) public virtual {
        require(account == _msgSender() || isApprovedForAll(account, _msgSender()), "ERC1155: caller is not owner nor approved");

        _burn(account, id, value);
    }

    function burnBatch(
        address account,
        uint256[] memory ids,
        uint256[] memory values
    ) public virtual {
        require(account == _msgSender() || isApprovedForAll(account, _msgSender()), "ERC1155: caller is not owner nor approved");

        _burnBatch(account, ids, values);
    }

    /**
     * @dev See {IERC1155-isApprovedForAll}. Approve `OPERATOR_ROLE` for all tokens.
     */
    function isApprovedForAll(address account, address operator) public view virtual override returns (bool) {
        return hasRole(OPERATOR_ROLE, operator) || super.isApprovedForAll(account, operator);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControlEnumerableUpgradeable, ERC1155) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {UUPS-_authorizeUpgrade}. Allows `DEFAULT_ADMIN_ROLE` to perform upgrade.
     */
    function _authorizeUpgrade(address) internal virtual override(UUPSUpgradeable) {
        _checkRole(DEFAULT_ADMIN_ROLE);
    }
}
