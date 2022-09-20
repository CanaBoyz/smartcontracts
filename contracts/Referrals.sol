// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

contract Referrals is AccessControlEnumerableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    event Register(address indexed user, address indexed refUser, uint256 indexed level);
    event Reward(address indexed user, address indexed refUser, uint256 indexed level, address token, uint256 amount);
    event Claim(address indexed user, address token, uint256 amount);
    event Flush(address token, uint256 amount);

    struct TokenState {
        uint256 amount;
        uint256[] levelRefsReward;
    }

    struct ReferralState {
        address upRef; // referral code, 0 === self
        mapping(address => TokenState) tokenStates; // tokenId => ref reward sum
        address[] downRefs;
        uint256[] levelRefsCount;
    }

    address payable private _wallet;
    //1% - 100, 10% - 1000 50% - 5000
    uint16[] private _levelRewardPercents;

    mapping(address => ReferralState) private _referrals;
    //total reserved amount per token
    mapping(address => uint256) private _totalReserved;

    function initialize(address payable walletAddress, uint16[] memory rewards) external initializer onlyProxy {
        __ReentrancyGuard_init_unchained();

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(OPERATOR_ROLE, _msgSender());

        require(walletAddress != address(0), "Zero wallet address");
        _wallet = walletAddress;

        // ref levels percents
        // 1% - 100, 10% - 1000 50% - 5000
        for (uint256 i = 0; i < rewards.length; i++) {
            _levelRewardPercents.push(rewards[i]);
        }
    }

    function setWallet(address payable walletAddress) external {
        _checkRole(DEFAULT_ADMIN_ROLE);
        require(walletAddress != address(0), "Zero wallet address");
        _wallet = walletAddress;
    }

    function getWallet() external view returns (address) {
        return _wallet;
    }

    //REFERRALS
    function getRefLevelRewardPercents() external view returns (uint16[] memory) {
        return _levelRewardPercents;
    }

    function setRefLevelRewardPercents(uint16[] memory percents) external {
        _checkRole(DEFAULT_ADMIN_ROLE);
        _levelRewardPercents = percents;
    }

    function getUpRef(address user) external view returns (address) {
        return _referrals[user].upRef;
    }

    function getRefs(address user) external view returns (address[] memory) {
        return _referrals[user].downRefs;
    }

    function getLevelRefsCount(address user) external view returns (uint256[] memory) {
        return _referrals[user].levelRefsCount;
    }

    function getLevelRefsReward(address user, address token) external view returns (uint256[] memory) {
        return _referrals[user].tokenStates[token].levelRefsReward;
    }

    function totalReserved(address token) external view returns (uint256) {
        return _totalReserved[token];
    }

    function awaitingAmount(address user, address token) public view returns (uint256) {
        return _referrals[user].tokenStates[token].amount;
    }

    function calcRefReward(uint256 amount) public view returns (uint256 refReward) {
        uint16[] memory percents = _levelRewardPercents;
        for (uint256 depth = 0; depth < percents.length; depth++) {
            refReward += (amount * percents[depth]) / 10000;
        }
    }

    function register(address refUser) external {
        _register(_msgSender(), refUser);
    }

    function _register(address user, address refUser) internal {
        // if referral address was given and player not tried to use their own,
        // and upper referral address not yet set
        if (refUser != address(0) && _referrals[user].upRef == address(0) && user != refUser) {
            _referrals[user].upRef = refUser;
            _referrals[refUser].downRefs.push(user);
            uint256 maxDepth = _levelRewardPercents.length;
            for (uint256 depth = 0; depth < maxDepth; depth++) {
                if (_referrals[refUser].levelRefsCount.length == depth) {
                    _referrals[refUser].levelRefsCount.push(1);
                } else {
                    _referrals[refUser].levelRefsCount[depth]++;
                }
                emit Register(user, refUser, depth);
                refUser = _referrals[refUser].upRef;
                if (refUser == address(0)) {
                    break;
                }
            }
        }
    }

    function regDistribute(
        address user,
        address token,
        uint256 amount,
        address refUser
    ) external payable {
        _checkRole(OPERATOR_ROLE);
        _register(user, refUser);

        distribute(user, token, amount);
    }

    function distribute(
        address user,
        address token,
        uint256 amount
    ) public payable {
        require(amount > 0, "Zero amount");
        require(user != address(0), "Zero recipient address");

        uint256 totalReward = _distribute(user, token, amount);
        if (token == address(0)) {
            require(msg.value >= totalReward, "Insuficient value");
            // change
            if (msg.value > totalReward) {
                //change return only to particular addresses
                payable(_msgSender()).transfer(msg.value - totalReward);
            }
        } else {
            IERC20Upgradeable(token).safeTransferFrom(_msgSender(), address(this), totalReward);
        }
    }

    function _distribute(
        address user,
        address token,
        uint256 amount
    ) internal returns (uint256 totalReward) {
        uint16[] memory percents = _levelRewardPercents;
        require(percents.length > 0, "Referral rewards not defined");
        uint256 reward;
        uint256 reserved = _totalReserved[token];
        address refUser = _referrals[user].upRef;
        for (uint256 depth = 0; depth < percents.length; depth++) {
            reward = (amount * percents[depth]) / 10000;
            if (refUser != address(0)) {
                _referrals[refUser].tokenStates[token].amount += reward;
                if (_referrals[refUser].tokenStates[token].levelRefsReward.length == depth) {
                    _referrals[refUser].tokenStates[token].levelRefsReward.push(reward);
                } else {
                    _referrals[refUser].tokenStates[token].levelRefsReward[depth] += reward;
                }

                emit Reward(user, refUser, depth, token, reward);
                reserved += reward;
                refUser = _referrals[refUser].upRef;
            }
            totalReward += reward;
        }
        _totalReserved[token] = reserved;
    }

    function claimReward(address payable user, address token) external nonReentrant returns (uint256) {
        _flushReserved(token);
        return _claimReward(user, token);
    }

    function _claimReward(address user, address token) internal returns (uint256 amount) {
        amount = _referrals[user].tokenStates[token].amount;
        require(amount > 0, "Zero transfer token amount");
        _referrals[user].tokenStates[token].amount = 0;
        _totalReserved[token] -= amount;
        if (token == address(0)) {
            payable(user).transfer(amount);
        } else {
            IERC20Upgradeable(token).safeTransfer(user, amount);
        }
        emit Claim(user, token, amount);
    }

    function flushReserved(address token) external nonReentrant {
        _flushReserved(token);
    }

    function _flushReserved(address token) internal returns (uint256 amount) {
        uint256 reserved = _totalReserved[token];
        if (token == address(0)) {
            amount = address(this).balance;
            if (amount > reserved) {
                unchecked {
                    amount -= reserved;
                }
                // _wallet.transfer(amount);
                //slither-disable-next-line arbitrary-send
                (bool success, ) = _wallet.call{value: amount}("");
                require(success, "Failed transfer to wallet");
                emit Flush(token, amount);
            }
        } else {
            amount = IERC20Upgradeable(token).balanceOf(address(this));
            if (amount > reserved) {
                unchecked {
                    amount -= reserved;
                }
                IERC20Upgradeable(token).safeTransferFrom(address(this), _wallet, amount);
                emit Flush(token, amount);
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
