// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// IERC20.sol :  https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.1.0/contracts/token/ERC20/IERC20.sol
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ISafeBet {
    struct BetOption {
        string name;
        uint256 id;
    }
    function version() external pure returns (string memory);
    function getTokenBalance() external view returns (uint256);

    function addBetOption(string calldata name) external returns (uint256);

    function existsBetOption(string calldata name) external view returns (bool);
    function listBetOptions() external view returns (BetOption[] memory);
}