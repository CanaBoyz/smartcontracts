// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../interfaces/IHook.sol";

contract ERC20Hooks {
    using EnumerableSet for EnumerableSet.AddressSet;

    event HookAdded(address addr);
    event HookRemoved(address addr);
    event HooksEnabled(bool enabled);

    EnumerableSet.AddressSet private _hooks;
    bool private _hooksEnabled;

    modifier withoutHooks() {
        bool enabled = _hooksEnabled;
        _hooksEnabled = false;
        _;
        _hooksEnabled = enabled;
    }

    function hooksEnabled() external view returns (bool) {
        return _hooksEnabled;
    }

    function hooks() external view returns (address[] memory) {
        return _hooks.values();
    }

    function hookExists(address hook) public view returns (bool) {
        return _hooks.contains(hook);
    }

    function hookByIndex(uint256 index) external view returns (address) {
        require(index < _hooks.length(), "ERC20Hook: Hook not exists");
        return _hooks.at(index);
    }

    function _enableHooks(bool enabled) internal {
        require(_hooksEnabled != enabled, "ERC20Hook: Hook enable state not changed");
        require(_hooks.length() > 0, "ERC20Hook: Hook not exists");
        _hooksEnabled = enabled;
        emit HooksEnabled(enabled);
    }

    function _addHook(address hook) internal {
        require(hook != address(0), "ERC20Hook: Hook zerro address");
        require(_hooks.add(hook), "ERC20Hook: Hook already added");
        emit HookAdded(hook);
    }

    function _removeHook(address hook) internal {
        require(hook != address(0), "ERC20Hook: Hook zerro address");
        require(_hooks.remove(hook), "ERC20Hook: Hook already removed");
        emit HookRemoved(hook);
    }

    function _applyHooks(
        address sender,
        address from,
        address to,
        uint256 amount
    ) internal {
        if (_hooksEnabled) {
            uint256 n = _hooks.length();
            for (uint256 i = 0; i < n; i++) {
                require(IHook(_hooks.at(i)).assure(sender, from, to, amount), "ERC20Hook: assure failed");
            }
        }
    }
}
