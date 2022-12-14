// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "./lib/ERC20Vesting.sol";
import "./lib/ERC20Hooks.sol";

/**
 * @dev {ERC20} Coin token
 */
contract Coin is AccessControlEnumerableUpgradeable, UUPSUpgradeable, PausableUpgradeable, ERC20Vesting, ERC20Hooks {
    bytes32 public constant MANAGE_ROLE = keccak256("MANAGE_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    function initialize(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply,
        address initialManager,
        uint256 feeFromForced,
        uint256 feeToForced,
        uint256 feeDefault
    ) external initializer {
        __Coin_init(name_, symbol_, initialSupply, initialManager, feeFromForced, feeToForced, feeDefault);
    }

    function __Coin_init(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply,
        address initialManager,
        uint256 feeFromForced,
        uint256 feeToForced,
        uint256 feeDefault
    ) internal virtual onlyInitializing {
        __Pausable_init_unchained();
        __ERC20Fee_init_unchained(name_, symbol_);
        __Coin_init_unchained(initialSupply, initialManager, feeFromForced, feeToForced, feeDefault);
    }

    function __Coin_init_unchained(
        uint256 initialSupply,
        address initialManager,
        uint256 feeFromForced,
        uint256 feeToForced,
        uint256 feeDefault
    ) internal virtual onlyInitializing {
        require(initialManager != address(0), "ERC20Initialize: inital manager is zero address");
        require(initialSupply != 0, "ERC20Initialize: inital supply is zero");

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MANAGE_ROLE, _msgSender());
        _setupRole(MANAGE_ROLE, initialManager);

        _setFees(feeFromForced, feeToForced, feeDefault);

        //exclude owner and this contract from fee
        _setExcludedFee(_msgSender(), true);
        _setExcludedFee(initialManager, true);

        //mint token to contract
        _mint(address(this), initialSupply);
    }

    /**
     * @dev See {ERC20Vesting-_transferableBalance}. Show spendable balance of tokens.
     */
    function balanceOf(address account) public view virtual override(ERC20Fee) returns (uint256) {
        return _transferableBalance(account, block.timestamp);
    }

    /**
     * @dev See {IERC20-balanceOf}. Show the account's total tokens balance.
     */
    function totalBalanceOf(address account) external view virtual returns (uint256) {
        return super.balanceOf(account);
    }

    /**
     * @dev See {ERC20Vesting-_assignVested}.
     */
    function assignVested(
        address receiver,
        uint256 amount,
        uint64 start,
        uint64 cliff,
        uint64 vested,
        bool revokable
    ) external returns (uint256) {
        _checkRole(MANAGE_ROLE);
        return _assignVested(receiver, amount, start, cliff, vested, revokable);
    }

    /**
     * @notice Revoke vesting #`vestingId` from `holder`, returning unvested tokens to the Token Manager
     * @param holder Address whose vesting to revoke
     * @param vestingId Numeric id of the vesting
     */
    function revokeVested(address holder, uint256 vestingId) external {
        _checkRole(MANAGE_ROLE);
        _revokeVested(holder, vestingId);
    }

    function revokeVestedAll(address holder) external {
        _checkRole(MANAGE_ROLE);
        _revokeVestedAll(holder);
    }

    function revokeVestedAllBatch(address[] memory holders) external {
        _checkRole(MANAGE_ROLE);
        for (uint256 i = 0; i < holders.length; i++) {
            _revokeVestedAll(holders[i]);
        }
    }

    /**
     * @dev See {ERC20Vesting-_distribute}.
     */
    function distribute(address[] memory receivers, uint256[] memory amounts) external {
        _checkRole(MANAGE_ROLE);
        _distribute(receivers, amounts);
    }

    /**
     * @dev See {ERC20Vesting-_distributeVested}.
     */
    function distributeVested(
        address[] memory receivers,
        uint256[] memory amounts,
        uint64 start,
        uint64 cliff,
        uint64 vesting,
        bool revokable
    ) external {
        _checkRole(MANAGE_ROLE);
        _distributeVested(receivers, amounts, start, cliff, vesting, revokable);
    }

    function setExcludedFee(address account, bool excluded) external {
        _checkRole(MANAGE_ROLE);
        _setExcludedFee(account, excluded);
    }

    function setForcedFee(address account, bool forced) external {
        _checkRole(MANAGE_ROLE);
        _setForcedFee(account, forced);
    }

    function setFees(
        uint256 feeFrom,
        uint256 feeTo,
        uint256 feeDefault
    ) external {
        _checkRole(MANAGE_ROLE);
        _setFees(feeFrom, feeTo, feeDefault);
    }

    function withdrawFee(address to) external {
        _checkRole(MANAGE_ROLE);
        _withdrawFee(to);
    }

    /**
     * @dev Pauses/Unpauses all token transfers.
     */
    function togglePause() external {
        _checkRole(DEFAULT_ADMIN_ROLE);
        if (paused()) {
            _unpause();
        } else {
            _pause();
        }
    }

    /**
     * @dev See {ERC20Hooks-_enableHooks}.
     */
    function enableHooks(bool enabled) external {
        _checkRole(DEFAULT_ADMIN_ROLE);
        _enableHooks(enabled);
    }

    /**
     * @dev See {ERC20Hooks-_addHook}.
     */
    function addHook(address hook) external {
        _checkRole(DEFAULT_ADMIN_ROLE);
        _addHook(hook);
    }

    /**
     * @dev See {ERC20Hooks-_removeHook}.
     */
    function removeHook(address hook) external {
        _checkRole(DEFAULT_ADMIN_ROLE);
        _removeHook(hook);
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
     * @dev See {ERC20-_beforeTokenTransfer}.
     *
     * Requirements:
     *
     * - the contract must not be paused.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);
        require(!paused(), "ERC20Pausable: token transfer while paused");
        _applyHooks(_msgSender(), from, to, amount);
    }

    /**
     * @dev Revoke tokens from the accounts of "bad players" marked as "blocked" by a hook
     * @notice During a call, all hooks will be temporarily disabled
     */
    function revokeBlocked(
        address hook,
        address revokeTo,
        address[] memory holders
    ) external onlyRole(DEFAULT_ADMIN_ROLE) withoutHooks {
        require(hookExists(hook), "ERC20Hook: Hook not exists");
        bool[] memory blocked = IHook(hook).getBlocked(holders);
        require(blocked.length == holders.length, "ERC20Hook: holders length missmatch");
        for (uint256 i = 0; i < holders.length; i++) {
            address holder = holders[i];
            if (blocked[i]) {
                _transfer(holders[i], revokeTo, balanceOf(holder));
            }
        }
    }

    /**
     * @dev See {UUPS-_authorizeUpgrade}. Allows `DEFAULT_ADMIN_ROLE` to perform upgrade.
     */
    function _authorizeUpgrade(address) internal virtual override(UUPSUpgradeable) {
        _checkRole(DEFAULT_ADMIN_ROLE);
    }
}
