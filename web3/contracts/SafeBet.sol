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

  /**
   * @dev DECIMALPERCENT is the representation of 100% using (2) decimal places
   * 100.00 = percentage accuracy (2) to 100%
   */
  uint256 public constant DECIMALPERCENT = 10000;
  
  /**
   * @dev Fee percentage charged by the safebet owner.
   *
   * For each amount received in the contract, a fee percentage is discounted.
   * This function returns this fee percentage.
   * Include 2 decimal places.
   */
  uint256 public feePercentageOwner;

  IERC20 public token;

  BetOption[] public betOptions;

  UserBet[] private _userBets;
  bool private _hasReferee;
  uint256 private _totalBetAmount;

  mapping(string => uint256) private betOptionIndex;
  mapping(uint256 => uint256) private betOptionTotalAmount;

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
  constructor(address tokenAddress, uint256 feePercentageOwnerParam) {
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    token = IERC20(tokenAddress);
    feePercentageOwner = feePercentageOwnerParam;
    _hasReferee = false;
    _totalBetAmount = 0;
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

  function makeBet(
    uint256 amount,
    uint256 betOptionId
  ) external override whenNotStopped returns (bool) {
    require(existsBetOptionId(betOptionId), "bet option does not exist");
    require(amount > 0, "bet amount must be greater than 0");

    UserBet memory b;
    b.user = _msgSender();
    b.betOptionId = betOptionId;
    b.amount = amount;
    _userBets.push(b);

    _totalBetAmount += amount;
    betOptionTotalAmount[betOptionId] += amount;

    //Transfer the tokens on IERC20, they should be already approved for the SafeBet Address to use them
    token.transferFrom(_msgSender(), address(this), amount);
    return true;
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
   * @dev Returns if a bet option is in the list of bet options.
   *
   * Parameters: string name of bet option
   *
   * Returns: boolean true if it is in the list
   *
   */
  function existsBetOptionName(string memory name)
    public
    view
    override
    returns (bool)
  {
    if (betOptionIndex[name] == 0) return false;
    else return true;
  }

  /**
   * @dev Returns if a bet option is in the list of bet options.
   *
   * Parameters: string name of bet option
   *
   * Returns: boolean true if it is in the list
   *
   */
  function existsBetOptionId(uint256 id)
    public
    view
    override
    returns (bool)
  {
    for (uint p = 0; p < betOptions.length; p++) {
      if (betOptions[p].id == id) {
        return true;
      }
    }
    return false;
  }

  /**
   * @dev List of bet options that are available to bet.
   *
   * Parameters: none
   *
   * Returns: an array of bet options
   *
   */
  function listBetOptions() 
    external 
    view 
    override 
    returns (BetOption[] memory) 
  {
    return betOptions;
  }

  function addBetOption(
    string calldata name
  ) external override onlyOwner whenNotStopped returns (uint256) {
    require(!existsBetOptionName(name), "bet options already exists");

    uint256 len = betOptions.length;
    BetOption memory b;
    b.name = name;
    b.id = len;
    betOptions.push(b);
    uint256 index = betOptions.length;
    betOptionIndex[name] = index;
    betOptionTotalAmount[b.id] = 0;
    return (index);
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
