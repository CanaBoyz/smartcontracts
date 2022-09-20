// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./lib/ERC20Fee.sol";

/**
 * @dev {ERC20} InnerCoin token
 */
contract InnerCoin is AccessControlEnumerableUpgradeable, UUPSUpgradeable, ERC20Fee {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    function initialize(
        string memory name_,
        string memory symbol_,
        uint256 feeFromForced,
        uint256 feeToForced,
        uint256 feeDefault
    ) external initializer {
        __ERC20Fee_init_unchained(name_, symbol_);
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setFees(feeFromForced, feeToForced, feeDefault);
        //exclude owner and this contract from fee
        _setExcludedFee(_msgSender(), true);
    }

    function setExcludedFee(address account, bool excluded) external {
        _checkRole(DEFAULT_ADMIN_ROLE);
        _setExcludedFee(account, excluded);
    }

    function setForcedFee(address account, bool forced) external {
        _checkRole(DEFAULT_ADMIN_ROLE);
        _setForcedFee(account, forced);
    }

    function setFees(
        uint256 feeFrom,
        uint256 feeTo,
        uint256 feeDefault
    ) external {
        _checkRole(DEFAULT_ADMIN_ROLE);
        _setFees(feeFrom, feeTo, feeDefault);
    }

    function withdrawFee(address to) external {
        _checkRole(DEFAULT_ADMIN_ROLE);
        _withdrawFee(to);
    }

    function mint(address to, uint256 amount) external {
        _checkRole(MINTER_ROLE);
        _mint(to, amount);
    }

    /**
     * @dev See {ERC20-_spendAllowance}.
     */
    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual override {
        if (!hasRole(OPERATOR_ROLE, spender)) {
            super._spendAllowance(owner, spender, amount);
        }
    }

    /**
     * @dev See {UUPS-_authorizeUpgrade}. Allows `DEFAULT_ADMIN_ROLE` to perform upgrade.
     */
    function _authorizeUpgrade(address) internal virtual override(UUPSUpgradeable) {
        _checkRole(DEFAULT_ADMIN_ROLE);
    }
}
