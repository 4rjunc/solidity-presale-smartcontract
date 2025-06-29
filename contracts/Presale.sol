// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;


import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

//import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

import "./ECT.sol";

contract Presale is ReentrancyGuard, Pausable {
  using SafeERC20 for IERC20;

  address private immutable USDC = block.chainid == 8453 ? 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913 : 0x036CbD53842c5426634e7929541eC2318f3dCF7e; // USDC mainnet : testnet | BASE

  /// @dev MULTISIGN WALLET ADDRESS 
  address private immutable MULTISIG_WALLET_ADDRESS = 0x0000000000000000000000000000000000000000; // TODO: Change this 
  
  /// @dev owner address 
  address private _owner;

  /// @dev Token interfaces
  ECT public immutable token; /// Change the interface to lottery token
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

  /// @dev thresholds of token amount and prices
  uint256[] public thresholds;
  uint256[] public prices;

  /// @dev tracks contribution of each investors 
  mapping(address => mapping(address => uint256)) public investments;
  
  /// @dev tracks token amount of investors 
  mapping(address => uint256) public investorsTokenBalance;

  /// @dev tracks early investors 
  mapping(address => bool) private earlyInvestorsMapping;
  
  /**
  * @dev event for token is bought 
  * @param buyer buyer who bought them 
  * @param tokensBought the bought tokens amount
  * @param amountPaid the amount of payment 
  */  
  event TokensBought(
    address indexed buyer,
    uint256 indexed tokensBought,
    uint256 indexed amountPaid,
    uint256 timestamp
  );
  
  /// @dev event for refunding all funds 
  event FundsRefunded(
    address indexed caller,
    uint256 indexed fundsAmount,
    uint256 timestamp
  );

  /// @dev event for claiming tokens
  event TokensClaimed(address indexed caller, uint256 indexed tokenAmount);

  /// @dev event for updating wallet address for withdrawing contract balance 
  event WalletUpdate(address indexed oldWallet, address indexed newWallet);

  /// @dev event for setting claim time 
  event ClaimTimeUpdated(
    uint256 indexed oldClaimTime,
    uint256 indexed newOwner
  );

  /// @dev event for transferring ownership 
  event OwnershipTransfered(
    address indexed previousOwner,
    address indexed newOwner
  );

  /// @dev validate if address is non-zero
  modifier notZeroAddress(address address_) {
      require(address_ != address(0), "Invalid address");
      _;
  }

  /// @dev validate presale startTime and endTime is valid 
  modifier isFuture(uint256 startTime_, uint256 duration_){
     require(startTime_ >= block.timestamp, "Invalid start time");
     require(duration_ > 0, "Invalid duration");
     _;
  }

  /// @dev validate softcap & hardcap setting
  modifier capSettingValid(uint256 softcap_, uint256 hardcap_) {
      require(softcap_ > 0, "Invalid softcap");
      require(hardcap_ > softcap_, "Invalid hardcap");
      _;
  }


  /// @dev validate if user can purchase certain amount of tokens at timestamp.
  modifier checkSaleState(uint256 tokenAmount_) {
      require(
          block.timestamp >= startTime && block.timestamp <= endTime,
          "Invalid time for buying the token."
      );

      // uint256 _tokensAvailable = tokensAvailable();
      //
      // require(
      //     tokenAmount_ <= _tokensAvailable && tokenAmount_ > 0,
      //     "Exceeds available tokens"
      // );
      _;
  }

  /// @dev validate if user is owner or not.
  modifier onlyOwner() {
      if (msg.sender != _owner) {
          revert NotOwner(); // Revert with custom error
      }
      _;
  }

  //Define a custom error for not being the owner
  error NotOwner();

  /**
     * @dev constructor for presale
     * @param softcap_ softcap for Presale, // 500,000
     * @param hardcap_ hardcap for Presale, // 1,000,000
     * @param startTime_ Presale start time, // 1662819200000
     * @param duration_ Presale duration, // 1762819200000
     * @param tokenAddress_ deployed ECT token address, // 0x810fa...
     * @param presaleTokenPercent_  ECT Token allocation percent for Presale, // 10%
     */
    constructor(
        uint256 softcap_,
        uint256 hardcap_,
        uint256 startTime_,
        uint256 duration_,
        address tokenAddress_,
        uint8 presaleTokenPercent_
    )
        capSettingValid(softcap_, hardcap_)
        notZeroAddress(tokenAddress_)
        isFuture(startTime_, duration_)
    {
        _owner = msg.sender;
        softcap = softcap_;
        hardcap = hardcap_;
        startTime = startTime_;
        endTime = startTime_ + duration_;

        token = ECT(tokenAddress_);
        presaleSupply = (token.totalSupply() * presaleTokenPercent_) / 100;

        // Initialize the thresholds and prices
        thresholds = [
            3_000_000_000 * 10 ** 18,
            7_000_000_000 * 10 ** 18,
            9_000_000_000 * 10 ** 18,
            presaleSupply
        ];
        prices = [80, 100, 120, 140]; // token price has 6 decimals.
    }

    /**
      * @dev transfer tokens from token contracts to presale contracts
      * @param presaleSupplyAmount_ amount of tokens for presale 
    */
   function transferTokensToPresale(uint256 presaleSupplyAmount_) public onlyOwner returns (bool) {
     require(presaleSupplyAmount_ > 0, "Amount must be greater than zero");
     require(
       token.balanceOf(msg.sender) >= presaleSupplyAmount_, "Insufficent balance"
     );
     require(block.timestamp < startTime, "Presale has already started");

     //Send the tokens to presale contract 
     SafeERC20.safeTransferFrom(
       token,
       msg.sender,
       address(this),
       presaleSupplyAmount_
     );
     return true;
   }

  /**
  * @dev internal functions to purchase LOTRY tokens with stable coin like USDT, USDC, DAI 
  * @param coin_ The stablecoin interface being used 
  * @param tokenAmount_ LOTRY token amount users willing to buy with 
  */ 
 function _buyWithCoin(
   IERC20 coin_,
   uint tokenAmount_
 ) internal checkSaleState(tokenAmount_) whenNotPaused nonReentrant{
   uint256 _coinAmount = estimatedCoinAmountForTokenAmount(tokenAmount_, coin_);
   uint8 _coinDecimals = 8; // Only of USDC 

   //Check allowance and balances
   // coin_.allowance refers to the amount of tokens a "spender" (like a smart contract) is permitted to withdraw from an "owner's" account 
   require(_coinAmount <= coin_.allowance(msg.sender, address(this)), "Insufficent allowance");
   require(_coinAmount <= coin_.balanceOf(msg.sender), "Insufficent Balance");

   // Code for buying token or make a data structure to hold details of buyers, the amount they send, how much LOTRY tokens alloted. 
   // Later when claim function is invoked by buyer after the presale ends. The tokens will be transfered to the buyer 

   // Emit the event of token buying 
   emit TokensBought(
     msg.sender,
     tokenAmount_,
     _coinAmount,
     block.timestamp
   );

   

 }

    /**
     * @dev Helper function to calculate coin amount for buying a certain amount of tokens. When user inputs tokenAmount and corresponding coinAmount is shown automatically
     * Takes into consideration price thresholds and returns the total coin amount needed.
     * @param tokenAmount_ token amount
     * @param coin_ stable coin type
     * @return _coinAmount calculated coin amount
     */
    function estimatedCoinAmountForTokenAmount(
        uint256 tokenAmount_,
        IERC20 coin_
    ) public view returns (uint256) {
      // function to calculate how much tokens is allocated to the buyer based on the USDC they paid
    }
}
