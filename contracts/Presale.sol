// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;


import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

//import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract Presale is ReentrancyGuard, Pausable {
  using SafeERC20 for IERC20;

  address private immutable USDC = block.chainid == 8453 ? 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913 : 0x036CbD53842c5426634e7929541eC2318f3dCF7e; // USDC mainnet : testnet | BASE

  /// @dev MULTISIGN WALLET ADDRESS 
  address private immutable MULTISIG_WALLET_ADDRESS = 0x0000000000000000000000000000000000000000; // TODO: Change this 
  
  /// @dev owner address 
  address private _owner;

  /// @dev Token interfaces
  // ECT public immutable token; /// Change the interface to lottery token
  IERC20 public immutable USDCInterface = IERC20(USDC);
  // IUniswapV2Router02 public immutable router = IUniswapV2Router02(ROUTER);

  /// @dev presale parameters 
  uint256 public softcap;
  uint256 public hardcap;
  uint256 public startTime;
  uint256 public endTime;
  uint256 public claimTime;
  uint256 public presaleSupply;

  /// @dev Total tokens sold in presale 
  uint256 public tokenTokensSold;

  /// @dev Amount raised in presale 
  uint256 public fundsRaised;

  /// @dev wallet account for raising funds 
  uint256 public wallet;

  /// @dev tracks investors 
  address[] public investors;

  /// @dev Tracks early investors who invested before reaching softcap. Unsold tokens will be distributed pro-rata to early investors
  address[] public earlyInvestors;


}
