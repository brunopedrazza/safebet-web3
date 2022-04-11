// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotStopped` and `whenStopped`, which can be applied to
 * the functions of your contract. Note that they will not be stopped by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Stoppable is Context {
    /**
     * @dev Emitted when the stop is triggered by `account`.
     */
    event Stopped(address account);

    bool private _stopped;

    /**
     * @dev Initializes the contract in unstopped state.
     */
    constructor() {
        _stopped = false;
    }

    /**
     * @dev Returns true if the contract is stopped, and false otherwise.
     */
    function stopped() public view virtual returns (bool) {
        return _stopped;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not stopped.
     *
     * Requirements:
     *
     * - The contract must not be stopped.
     */
    modifier whenNotStopped() {
        require(!stopped(), "Stoppable: stopped");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is stopped.
     *
     * Requirements:
     *
     * - The contract must be stopped.
     */
    modifier whenStopped() {
        require(stopped(), "Stoppable: not stopped");
        _;
    }

    /**
     * @dev Triggers stopped state.
     * Once stopped, the contract can not be started again.
     *
     * Requirements:
     *
     * - The contract must not be stopped.
     */
    function _stop() internal virtual whenNotStopped {
        _stopped = true;
        emit Stopped(_msgSender());
    }
}
