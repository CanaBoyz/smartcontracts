// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "../interfaces/IHook.sol";

error RecipientBlacklisted();
error SenderBlacklisted();

/**
 * @dev Hook with black/white lists on token transfer
 */
contract HookBlackWhiteList is IHook, OwnableUpgradeable, UUPSUpgradeable {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    EnumerableSetUpgradeable.AddressSet private _blackListTo;
    EnumerableSetUpgradeable.AddressSet private _blackListFrom;
    EnumerableSetUpgradeable.AddressSet private _whiteListTo;
    EnumerableSetUpgradeable.AddressSet private _whiteListFrom;

    function initialize() external initializer {
        __HookBlackWhiteList_init();
    }

    function __HookBlackWhiteList_init() internal onlyInitializing {
        __Ownable_init_unchained();
        __HookBlackWhiteList_init_unchained();
    }

    function __HookBlackWhiteList_init_unchained() internal onlyInitializing {}

    function assure(
        address, // sender
        address from,
        address to,
        uint256 // amount
    ) external view returns (bool allow) {
        if (_blackListTo.contains(to) && !_whiteListFrom.contains(from)) revert RecipientBlacklisted();
        if (_blackListFrom.contains(from) && !_whiteListTo.contains(to)) revert SenderBlacklisted();
        return true;
    }

    /**
     * @dev Returns blocked status for holders
     * @notice Can be called only from Token contract
     */
    function getBlocked(address[] memory holders) external view returns (bool[] memory blocked) {}

    function isBlackListTo(address account) external view returns (bool) {
        return _blackListTo.contains(account);
    }

    function isBlackListFrom(address account) external view returns (bool) {
        return _blackListFrom.contains(account);
    }

    function isWhiteListTo(address account) external view returns (bool) {
        return _whiteListTo.contains(account);
    }

    function isWhiteListFrom(address account) external view returns (bool) {
        return _whiteListFrom.contains(account);
    }

    // _blackListTo
    function addBlackListTo(address account) external onlyOwner {
        _blackListTo.add(account);
        _whiteListFrom.remove(account);
        _whiteListTo.remove(account);
    }

    function removeBlackListTo(address account) external onlyOwner {
        _blackListTo.remove(account);
    }

    // _blackListFrom
    function addBlackListFrom(address account) external onlyOwner {
        _blackListFrom.add(account);
        _whiteListFrom.remove(account);
        _whiteListTo.remove(account);
    }

    function removeBlackListFrom(address account) external onlyOwner {
        _blackListFrom.remove(account);
    }

    // _whiteListTo
    function addWhiteListTo(address account) external onlyOwner {
        _whiteListTo.add(account);
        _blackListFrom.remove(account);
        _blackListTo.remove(account);
    }

    function removeWhiteListTo(address account) external onlyOwner {
        _whiteListTo.remove(account);
    }

    // _whiteListFrom
    function addWhiteListFrom(address account) external onlyOwner {
        _whiteListFrom.add(account);
        _blackListFrom.remove(account);
        _blackListTo.remove(account);
    }

    function removeWhiteListFrom(address account) external onlyOwner {
        _whiteListFrom.remove(account);
    }

    /**
     * @dev See {UUPS-_authorizeUpgrade}. Allows `DEFAULT_ADMIN_ROLE` to perform upgrade.
     */
    function _authorizeUpgrade(address) internal virtual override(UUPSUpgradeable) onlyOwner {}
}
