// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// IERC20.sol :  https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.1.0/contracts/token/ERC20/IERC20.sol
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ISafeBet {
    function version() external pure returns (string memory);
    function getTokenBalance() external view returns (uint256);
}