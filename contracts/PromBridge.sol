// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

error AlreadyBridged();
error NotEnoughValue();
error IncorrectFeeValue();

contract PromBridge is ReentrancyGuard, AccessControl {
    using SafeERC20 for IERC20;
    uint256 public fee;
    IERC20 public Prom;

    bytes32 internal constant ADMIN = keccak256("ADMIN");
    bytes32 internal constant ULTIMATE_ADMIN = keccak256("ULTIMATE_ADMIN");

    mapping(bytes32 => bool) public usedTxHashes;

    constructor(
        IERC20 _prom,
        uint256 _fee,
        address _ultimateAdmin,
        address _admin
    ) {
        Prom = _prom;
        fee = _fee;
        _grantRole(ULTIMATE_ADMIN, _ultimateAdmin);
        _setRoleAdmin(ADMIN, ULTIMATE_ADMIN);
        _grantRole(ADMIN, _admin);
    }

    event Deposited(address indexed sender, uint256 indexed amount);

    event Forwarded(
        address indexed sender,
        uint256 indexed amount,
        bytes32 indexed txHash
    );

    function deposit(uint256 _amount) external payable nonReentrant {
        if (msg.value != fee) {
            revert IncorrectFeeValue();
        }
        Prom.safeTransferFrom(msg.sender, address(this), _amount);
        emit Deposited(msg.sender, _amount);
    }

    function forward(
        bytes32 _txHash,
        address _receiver,
        uint256 _amount
    ) external onlyRole(ADMIN) {
        if (usedTxHashes[_txHash]) {
            revert AlreadyBridged();
        }
        usedTxHashes[_txHash] = true;
        Prom.safeTransfer(_receiver, _amount);
        emit Forwarded(_receiver, _amount, _txHash);
    }

    function withdrawAdmin(
        address _asset,
        uint256 _amount
    ) external onlyRole(ADMIN) {
        if (_asset == address(0)) {
            (bool success, ) = payable(msg.sender).call{value: _amount}("");
            require(success, "Should transfer ethers");
        } else {
            Prom.safeTransfer(msg.sender, _amount);
        }
    }

    function updateFee(uint256 _fee) external onlyRole(ADMIN) {
        fee = _fee;
    }
}
