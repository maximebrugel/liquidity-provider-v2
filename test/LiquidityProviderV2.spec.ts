const { expect } = require("chai");
import { ethers } from "hardhat";

describe("LiquidityProviderV2 contract", function () {
  let owner;
  let dev;
  let addr1;
  let addr2;
  let lptoken;
  let addrs;
  let uniswapPairContract;
  let uniswapRouterContract;
  let uniswapRouter;
  let liquidityProviderContract;
  let liquidityProvider;
  let wethContract;
  let wethTest;
  let testERC20Contract;
  let testERC20a;
  let testERC20b;
  let pair_A_ETH;
  let pair_A_B;

  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    testERC20Contract = await ethers.getContractFactory("TestERC20");
    wethContract = await ethers.getContractFactory("WETH");
    liquidityProviderContract = await ethers.getContractFactory(
      "LiquidityProviderV2"
    );

    [owner, dev, addr1, addr2, lptoken, ...addrs] = await ethers.getSigners();

    // Deploy testERC20
    testERC20a = await testERC20Contract.deploy(0);
    testERC20b = await testERC20Contract.deploy(0);
    wethTest = await wethContract.deploy();

    // Deploy uniswap
    const UniswapV2FactoryBytecode =
      require("@uniswap/v2-core/build/UniswapV2Factory.json").bytecode;
    const UniswapV2Factory = await ethers.getContractFactory(
      [
        "constructor(address _feeToSetter)",
        "function createPair(address tokenA, address tokenB) external returns (address pair)",
        "function feeTo() external view returns (address)",
        "function feeToSetter() external view returns (address)",
        "function getPair(address tokenA, address tokenB) external view returns (address pair)",
        "function allPairs(uint) external view returns (address pair)",
        "function allPairsLength() external view returns (uint)",
        "function setFeeTo(address) external",
        "function setFeeToSetter(address) external",
      ],
      UniswapV2FactoryBytecode
    );

    const UniswapV2Router02Bytecode =
      require("@uniswap/v2-periphery/build/UniswapV2Router02.json").bytecode;
    uniswapRouterContract = await ethers.getContractFactory(
      [
        "constructor(address _factory, address _WETH)",
        "function addLiquidityETH(address token, uint amountTokenDesired, uint amountTokenMin, uint amountETHMin, address to, uint deadline) external payable returns (uint amountToken, uint amountETH, uint liquidity)",
        "function addLiquidity(address tokenA, address tokenB, uint amountADesired, uint amountBDesired, uint amountAMin, uint amountBMin, address to, uint deadline) external returns (uint amountA, uint amountB, uint liquidity)",
        "function WETH() external pure returns (address)",
        "function factory() external pure returns (address)",
        "function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline) external payable returns (uint[] memory amounts)",
        "function swapTokensForExactTokens(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline) external returns (uint[] memory amounts)",
        "function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut)",
      ],
      UniswapV2Router02Bytecode
    );

    const UniswapV2Pair =
      require("@uniswap/v2-core/build/UniswapV2Pair.json").bytecode;
    uniswapPairContract = await ethers.getContractFactory(
      [
        "function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast)",
        "function sync() external",
        "function balanceOf(address owner) external view returns (uint)",
        "function approve(address spender, uint value) external returns (bool)",
        "function totalSupply() external view returns (uint)",
      ],
      UniswapV2Pair
    );

    const uniswapV2Factory = await UniswapV2Factory.deploy(owner.address);
    uniswapRouter = await uniswapRouterContract.deploy(
      uniswapV2Factory.address,
      wethTest.address
    );

    liquidityProvider = await liquidityProviderContract.deploy();

    await initSpending(owner);
    await initSpending(addr1);

    // Add initial liquidity
    let liquidityAmount = ethers.utils.parseEther("100");
    let deadline = await getDeadline();
    await uniswapRouter.addLiquidity(
      testERC20a.address,
      wethTest.address,
      liquidityAmount,
      liquidityAmount,
      0,
      0,
      owner.address,
      deadline
    );

    pair_A_ETH = await uniswapV2Factory.getPair(
      testERC20a.address,
      wethTest.address
    );

    await uniswapRouter.addLiquidity(
      testERC20a.address,
      testERC20b.address,
      liquidityAmount,
      liquidityAmount,
      0,
      0,
      owner.address,
      deadline
    );

    pair_A_B = await uniswapV2Factory.getPair(
      testERC20a.address,
      testERC20b.address
    );

    const weth = await uniswapRouter.WETH();

    expect(weth).to.equal(wethTest.address);
  });

  it("Should add liquidity with only ETH", async function () {
    let liquidityEth = {
      value: ethers.utils.parseEther("1.0"),
    };

    const pair = await uniswapPairContract.attach(pair_A_ETH);
    let reserve0, reserve1;

    [reserve0, reserve1] = await pair.getReserves();

    // Before adding liquidity reserve0 and reserve1 must equal to 100
    expect(reserve0.toString()).to.equal(
      ethers.utils.parseEther("100").toString()
    );
    expect(reserve1.toString()).to.equal(
      ethers.utils.parseEther("100").toString()
    );

    await liquidityProvider.addLiquidityOnlyETH(
      uniswapRouter.address,
      testERC20a.address,
      liquidityEth
    );

    [, reserve1] = await pair.getReserves();
    expect(reserve1.toString()).to.equal(
      ethers.utils.parseEther("101").toString()
    );
  });

  it("Should add liquidity to tokenA/tokenB pair (tokenB balance > 100)", async function () {
    const pair = await uniswapPairContract.attach(pair_A_B);
    const initalReserve = ethers.utils.parseEther("100");
    let reserve0, reserve1;

    [reserve0, reserve1] = await pair.getReserves();

    // Before adding liquidity reserve0 and reserve1 must equal to 100
    expect(reserve0.toString()).to.equal(initalReserve.toString());
    expect(reserve1.toString()).to.equal(initalReserve.toString());

    const liquidity = ethers.utils.parseEther("1");
    const amountOut = await uniswapRouter.getAmountOut(
      liquidity,
      reserve0,
      reserve1
    );

    await liquidityProvider.addLiquidityERC20(
      uniswapRouter.address,
      testERC20a.address,
      testERC20b.address,
      liquidity
    );

    [reserve0, reserve1] = await pair.getReserves();
    expect(reserve1.toString()).to.equal(
      amountOut.add(initalReserve).toString()
    );
    expect(reserve0.toString()).to.equal(
      amountOut.add(initalReserve).toString()
    );
  });

  it("Should add liquidity to tokenA/tokenB pair (tokenB balance = 0)", async function () {
    const pair = await uniswapPairContract.attach(pair_A_B);
    const initalReserve = ethers.utils.parseEther("100");
    let reserve0, reserve1;

    [reserve0, reserve1] = await pair.getReserves();

    // Before adding liquidity reserve0 and reserve1 must equal to 100
    expect(reserve0.toString()).to.equal(initalReserve.toString());
    expect(reserve1.toString()).to.equal(initalReserve.toString());

    const liquidity = ethers.utils.parseEther("1");
    // The owner send 1 tokenA, but addr2 has 0 tokenB
    await testERC20a.transfer(addr2.address, liquidity);

    const test = ethers.utils.parseEther("0.5");
    await testERC20b.transfer(addr2.address, test);

    await testERC20a
      .connect(addr2)
      .approve(liquidityProvider.address, initalReserve);
    await testERC20b
      .connect(addr2)
      .approve(liquidityProvider.address, initalReserve);

    await liquidityProvider
      .connect(addr2)
      .addLiquidityERC20(
        uniswapRouter.address,
        testERC20a.address,
        testERC20b.address,
        liquidity
      );

    [reserve0] = await pair.getReserves();
    expect(reserve0.gt(initalReserve)).to.true;
  });

  it("Should be able to remove liquidity from A/B", async function () {
    const pair = await uniswapPairContract.attach(pair_A_B);
    const initalReserve = ethers.utils.parseEther("100");
    let reserve0, reserve1;

    [reserve0, reserve1] = await pair.getReserves();

    // Before adding liquidity reserve0 and reserve1 must equal to 100
    expect(reserve0.toString()).to.equal(initalReserve.toString());
    expect(reserve1.toString()).to.equal(initalReserve.toString());

    let currentLP = await pair.balanceOf(owner.address);

    await pair.approve(liquidityProvider.address, currentLP);

    // Remove half of the liquidity
    await liquidityProvider.removeLiquidity(
      uniswapRouter.address,
      pair.address,
      currentLP.div(2)
    );

    [reserve0, reserve1] = await pair.getReserves();
    expect(
      reserve0.gte(ethers.utils.parseEther("49")) &&
        reserve0.lte(ethers.utils.parseEther("51"))
    ).to.be.true;
    expect(
      reserve1.gte(ethers.utils.parseEther("49")) &&
        reserve0.lte(ethers.utils.parseEther("51"))
    ).to.be.true;
  });

  it("Should be able to remove liquidity from A/ETH", async function () {
    const pair = await uniswapPairContract.attach(pair_A_ETH);
    const initalReserve = ethers.utils.parseEther("100");
    let reserve0, reserve1;

    [reserve0, reserve1] = await pair.getReserves();

    // Before adding liquidity reserve0 and reserve1 must equal to 100
    expect(reserve0.toString()).to.equal(initalReserve.toString());
    expect(reserve1.toString()).to.equal(initalReserve.toString());

    let currentLP = await pair.balanceOf(owner.address);

    await pair.approve(
      liquidityProvider.address,
      initalReserve.add(initalReserve)
    );

    // Remove half of the liquidity
    await liquidityProvider.removeLiquidity(
      uniswapRouter.address,
      pair.address,
      currentLP.div(2)
    );

    [reserve0, reserve1] = await pair.getReserves();
    expect(
      reserve0.gte(ethers.utils.parseEther("49")) &&
        reserve0.lte(ethers.utils.parseEther("51"))
    ).to.be.true;
    expect(
      reserve1.gte(ethers.utils.parseEther("49")) &&
        reserve0.lte(ethers.utils.parseEther("51"))
    ).to.be.true;
  });

  async function initSpending(receiver) {
    let amount = ethers.utils.parseEther("10000000");
    await testERC20a.connect(receiver).mint(receiver.address, amount);
    await testERC20b.connect(receiver).mint(receiver.address, amount);
    await wethTest.connect(receiver).mintToken(amount);

    await wethTest.connect(receiver).approve(uniswapRouter.address, amount);
    await testERC20a.connect(receiver).approve(uniswapRouter.address, amount);
    await testERC20b.connect(receiver).approve(uniswapRouter.address, amount);

    await wethTest.connect(receiver).approve(liquidityProvider.address, amount);
    await testERC20a
      .connect(receiver)
      .approve(liquidityProvider.address, amount);
    await testERC20b
      .connect(receiver)
      .approve(liquidityProvider.address, amount);
  }

  async function getDeadline() {
    const blocknumber = await ethers.provider.getBlockNumber();
    const lastblock = await ethers.provider.getBlock(blocknumber);
    return lastblock.timestamp + 60 * 60;
  }
});
