pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@contracts/oracles/MixOracle/TarotOracle/interfaces/IUniswapV2Pair.sol";
import "@contracts/DebitaProxyContract.sol";
import {console} from "forge-std/console.sol";

interface IPyth {
    function getThePrice(address tokenAddress) external returns (int);
}

interface ITarotOracle {
    function initialize(address uniswapV2Pair) external;
    function getResult(
        address uniswapV2Pair
    ) external returns (uint224 price, uint32 T);
}

contract MixOracle {
    address multisig; //
    address tarotOracleImplementation; // TarotOracle implementation
    address debitaPythOracle; // DebitaPythOracle
    bool isPaused;
    uint deployedAt;

    mapping(address => bool) public isSenderAManager; // Managers will be able to pause the contract or specific price feeds but not set them
    mapping(address => address) public AttachedUniswapPair; // address of the token ==> address of the UniswapPair
    mapping(address => address) public AttachedPricedToken; // address of the token you want to know the price ==> address of the token that the price will be returned
    mapping(address => bool) public isFeedAvailable; // address of the UniswapPair ==> is the feed available?

    constructor(address _tarotOracleImplementation, address _debitaPythOracle) {
        multisig = msg.sender;
        isSenderAManager[msg.sender] = true;
        tarotOracleImplementation = _tarotOracleImplementation;
        debitaPythOracle = _debitaPythOracle;
        deployedAt = block.timestamp;
    }

    function getThePrice(address tokenAddress) public returns (int) {
        // get tarotOracle address
        require(!isPaused, "Contract is paused");

        address uniswapPair = AttachedUniswapPair[tokenAddress];
        require(isFeedAvailable[uniswapPair], "Price feed not available");
        // get twap price from token1 in token0

        address attached = AttachedPricedToken[tokenAddress];

        // Get the price from the pyth contract, no older than 20 minutes
        // get usd price of token0
        int attachedTokenPrice = IPyth(debitaPythOracle).getThePrice(attached);
        uint decimalsToken1 = ERC20(attached).decimals();
        uint decimalsToken0 = ERC20(tokenAddress).decimals();

        uint attachedAmount = IUniswapV2Pair(uniswapPair).current(
            tokenAddress,
            10 ** decimalsToken0
        );
        uint realPrice = ((uint(attachedTokenPrice)) * attachedAmount) /
            (10 ** decimalsToken1);
        require(realPrice > 0, "Invalid price");
        return int(uint(realPrice));
    }

    function setAttachedTarotPriceOracle(
        address uniswapV2Pair,
        address key,
        address attached
    ) public {
        require(multisig == msg.sender, "Only multisig can set price feeds");

        require(
            AttachedUniswapPair[uniswapV2Pair] == address(0),
            "Uniswap pair already set"
        );

        address token0 = IUniswapV2Pair(uniswapV2Pair).token0();
        address token1 = IUniswapV2Pair(uniswapV2Pair).token1();
        require(token0 == key || token1 == key, "Key is not in the pair");
        require(attached != key, "Attached token is the same as key");
        AttachedUniswapPair[key] = uniswapV2Pair;
        AttachedPricedToken[key] = attached;
        isFeedAvailable[uniswapV2Pair] = true;
    }

    function setManager(address manager, bool status) public {
        require(multisig == msg.sender, "Only multisig can set manager");
        isSenderAManager[manager] = status;
    }

    function changeMultisig(address _newMultisig) public {
        require(multisig == msg.sender, "Only multisig can change multisig");
        // only in the first 6 hours after deployment
        require(block.timestamp < deployedAt + 6 hours, "Time passed");
        multisig = _newMultisig;
    }

    function pauseContract() public {
        require(
            isSenderAManager[msg.sender],
            "Only manager can pause contract"
        );
        isPaused = true;
    }

    function reactivateContract() public {
        require(multisig == msg.sender, "Only multisig can change status");
        isPaused = false;
    }

    function pauseStatusPriceId(address uniswapPair) public {
        require(isSenderAManager[msg.sender], "Only manager can change status");
        isFeedAvailable[uniswapPair] = false;
    }

    function reactivateStatusPriceId(address uniswapPair) public {
        require(multisig == msg.sender, "Only multisig can change status");
        isFeedAvailable[uniswapPair] = true;
    }
}
