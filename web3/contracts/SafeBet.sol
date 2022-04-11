// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


/// @title SafeBet
/// @author Bruno Pedrazza

// AccessControl.sol :  https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.1.0/contracts/access/AccessControl.sol
// Pausable.sol :       https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.1.0/contracts/security/Pausable.sol
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./ISafeBet.sol";
import "./Stoppable.sol";

struct BetOption {
    string name;
    uint32 id;
}

/**
 * @dev SafeBet
 *
 * Author: Bruno Pedrazza
 *
 * It uses [Open Zeppelin Contracts]
 * (https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.1.0/)
 *
 */
contract SafeBet is AccessControl, ISafeBet, Stoppable {
  address private constant ZERO_ADDRESS = address(0);
  bytes32 private constant NULL_HASH = bytes32(0);

  bytes32 public constant REFEREE_ROLE = keccak256("REFEREE_ROLE");
  bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

  IERC20 public token;

  bool private _hasReferee;

  /**
   * @dev Function called only when the smart contract is deployed.
   *
   * Parameters:
   * - address tokenAddress - address of the token to be used to bet and receive claims
   *
   * Actions:
   * - the transaction's sender will be added in the DEFAULT_ADMIN_ROLE.
   * - the token will be defined by the parameter tokenAddress
   */
  constructor(address tokenAddress) {
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    token = IERC20(tokenAddress);
    _hasReferee = false;
  }

  /**
   * @dev Returns true if the contract has some account with referee role, and false otherwise.
   */
  function hasReferee() public view virtual returns (bool) {
      return _hasReferee;
  }

  /**
     * @dev Modifier to make a function callable only when the contract does not have a referee.
     *
     * Requirements:
     *
     * - The contract must not have an account with referee role
     */
    modifier whenNotHasReferee() {
        require(!hasReferee(), "has referee");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract has a referee.
     *
     * Requirements:
     *
     * - The contract must have a referee.
     */
    modifier whenHasReferee() {
        require(hasReferee(), "does not has referee");
        _;
    }

  /**
   * @dev Modifier which verifies if the caller is an owner,
   * it means he has the role `DEFAULT_ADMIN_ROLE`.
   *
   * The role `DEFAULT_ADMIN_ROLE` is defined by Open Zeppelin's AccessControl smart contract.
   *
   * By default (setted in the constructor) the account which deployed this smart contract is in this role.
   *
   * This owner can add / remove other owners.
   */
  modifier onlyOwner() {
    require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "not owner");
    _;
  }

  /**
   * @dev Modifier which verifies if the caller is a referee,
   * it means he has the role `REFEREE_ROLE`.
   *
   * Role REFEREE are referred to its `bytes32` identifier,
   * defined in the `public constant` called REFEREE_ROLE.
   * It should be exposed in the external API and be unique.
   *
   * Role REFEREE is used to define which bet option is the winner one.
   * This role is responsible for enabling the user's claims.
   */
  modifier onlyReferee() {
    require(hasRole(REFEREE_ROLE, _msgSender()), "not referee");
    _;
  }

  /**
   * @dev Modifier which verifies if the caller is a admin,
   * it means he has the role `ADMIN_ROLE`.
   *
   * Role ADMIN are referred to its `bytes32` identifier,
   * defined in the `public constant` called ADMIN_ROLE.
   * It should be exposed in the external API and be unique.
   *
   * Role ADMIN is used to add/remove bet options.
   */
  modifier onlyAdmin() {
    require(hasRole(ADMIN_ROLE, _msgSender()), "not admin");
    _;
  }

  /**
   * @dev Function which returns the safebet's contract version.
   *
   * This is a fixed value define in source code.
   *
   * Parameters: none
   *
   * Returns: string
   */
  function version() external pure override returns (string memory) {
    return "v0";
  }

  /**
   * @dev Private function to compare two strings
   * and returns `true` if the strings are equal,
   * otherwise it returns false.
   *
   * Parameters: stringA, stringB
   *
   * Returns: bool
   */
  function compareStrings(string memory a, string memory b)
    private
    pure
    returns (bool)
  {
    return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
  }

  /**
   * @dev Returns token balance.
   *
   * Parameters: none
   *
   * Returns: integer amount of tokens in this contract
   *
   */
  function getTokenBalance() external view override returns (uint256) {
    return token.balanceOf(address(this));
  }

  /**
   * @dev This function add an address in the `REFEREE_ROLE`.
   *
   * Only owner can call it.
   * The contract must not have a referee.
   *
   * Can not be called if the contract is paused.
   * This role can not be revoked by the owner.
   * Only one account can have a referee role.
   *
   * Parameters: address of referee to be added
   *
   * Returns: bool - true if it is sucessful
   *
   */
  function addReferee(address account)
    external
    onlyOwner
    whenNotHasReferee
    whenNotStopped
    returns (bool)
  {
    require(!hasRole(ADMIN_ROLE, account), "is admin");
    grantRole(REFEREE_ROLE, account);
    _hasReferee = true;
    return true;
  }

  /**
   * @dev This function allows a user to renounce a role
   *
   * Parameters: bytes32 role, address account
   *
   * Returns: none
   *
   * Requirements:
   *
   * - An owner can not renounce the role DEFAULT_ADMIN_ROLE.
   * - Can only renounce roles for your own account.
   *
   */
  function renounceRole(bytes32 role, address account) public virtual override {
    require(role != DEFAULT_ADMIN_ROLE, "can not renounce role owner");
    require(account == _msgSender(), "can only renounce roles for self");
    super.renounceRole(role, account);
  }

  /**
   * @dev This function allows to revoke a role
   *
   * Parameters: bytes32 role, address account
   *
   * Returns: none
   *
   * Requirements:
   *
   * - An owner can not revoke yourself in the role DEFAULT_ADMIN_ROLE.
   *
   */
  function revokeRole(bytes32 role, address account)
    public
    virtual
    override
    onlyRole(getRoleAdmin(role))
  {
    if (role == DEFAULT_ADMIN_ROLE) {
      require(account != _msgSender(), "can not revoke yourself in role owner");
    }
    super.revokeRole(role, account);
  }

  /**
   * @dev This function stops the contract.
   *
   * Only owner can call it.
   *
   * Parameters: none
   *
   * Returns: none
   *
   * Requirements:
   *
   * - The contract must not be stopped.
   * - The contract must have a referee.
   *
   */
  function stop() external 
    onlyOwner
    whenHasReferee
  {
    /**
     * @dev See {Stoppable-_stop}.
     *
     * Requirements:
     *
     * - The contract must not be stopped.
     */
    _stop();
  }
}
