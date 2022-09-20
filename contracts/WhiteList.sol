// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

/**
 * @dev {ERC721} base card template
 */
contract WhiteList is AccessControlEnumerableUpgradeable, UUPSUpgradeable {
  using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

  bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

  EnumerableSetUpgradeable.AddressSet private _acl;

  function initialize() external initializer {
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    _setupRole(OPERATOR_ROLE, _msgSender());
  }

  function addToList(address[] memory accounts) external onlyRole(OPERATOR_ROLE) {
    for (uint256 i = 0; i < accounts.length; i++) {
      _acl.add(accounts[i]);
    }
  }

  function removeFromList(address[] memory accounts) external onlyRole(OPERATOR_ROLE) {
    for (uint256 i = 0; i < accounts.length; i++) {
      _acl.remove(accounts[i]);
    }
  }

  function isInList(address account) external view returns (bool) {
    return _acl.contains(account);
  }

  function resetList(address[] memory accounts) external onlyRole(OPERATOR_ROLE) {
    address account;
    //clear
    while (_acl.length() > 0) {
      account = _acl.at(_acl.length() - 1);
      _acl.remove(account);
    }
    for (uint256 i = 0; i < accounts.length; i++) {
      _acl.add(accounts[i]);
    }
  }

  function getList() external view returns (address[] memory) {
    return _acl.values();
  }

  /**
   * @dev See {UUPS-_authorizeUpgrade}. Allows `DEFAULT_ADMIN_ROLE` to perform upgrade.
   */
  function _authorizeUpgrade(address) internal virtual override(UUPSUpgradeable) {
    _checkRole(DEFAULT_ADMIN_ROLE, _msgSender());
  }
}
