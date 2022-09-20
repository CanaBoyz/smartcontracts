// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

/**
 * @dev Common shared errors
 */

error AlreadyExists();
error NotExists();
error ZeroAddress();
error ZeroValue();
error EmptyInput();
error OutOfBounds();
error NonceMissmatch();
error CallerIsNotOwner();
error CallerIsNotOwnerNorApproved();
error TransferWhilePaused();
error WrongInputParams();
error NotEnoughMoney();
error FailedToTransferMoney();
error StartDateNotDefined();
error SaleNotStarted();
error NoMoreRemainAmount();
error InsufficientAmount();
error TokenNotDefined();

error NoMinterRole();
error NoOperatorRole();
error NoAdminRole();