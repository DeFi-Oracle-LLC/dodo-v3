import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { GOERLI_CONFIG as config } from "../../config/goerli-config";
import { BigNumber } from "@ethersproject/bignumber";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, ethers } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const d = config.deployedAddress;
  const ONE = BigNumber.from(padZeros(1, 18));
  
  // await setInterestRates();
  // await executeEpochUpdate();
  // await setMaxDeposits();
  // await ownerDepositAllTokens();
  // await userDepositAllTokens();
  // await ownerWithdraw();
  // await getPoolInfo();

  async function ownerWithdraw() {
    const d3MM = await ethers.getContractAt("D3MM", d.D3MM);
    await d3MM.ownerWithdraw("0xb37136B338C6cC0E459A35fe9Aa036f6b5A147c0", "0xB79B2fe44E8e497034f05d698D9E2cd235B9a754", BigNumber.from(padZeros(1000000000100010010, 8)))
  }

  // 1. setting interest rates for all tokens ✅
  async function setInterestRates() {
    const d = config.deployedAddress;
    const d3MM = await ethers.getContractAt("D3MM", d.D3MM);
    const tokens = [d.wbtcAddress, d.daiAddress, d.dodoAddress];
    const rate1 = BigNumber.from(padZeros(20, 16)); // 20%
    const rate2 = BigNumber.from(padZeros(10, 16)); // 10%
    const rate3 = BigNumber.from(padZeros(20, 16)); // 40%
    //const rate4 = BigNumber.from(padZeros(50, 16)); // 50%
    const rates = [rate1, rate2, rate3];
    console.log("setting interest rates...")
    await d3MM.setNextEpoch(tokens, rates);
  }

  // 2. excute epoch update ✅
  async function executeEpochUpdate() {
    const d = config.deployedAddress;
    const d3MM = await ethers.getContractAt("D3MM", d.D3MM);
    await d3MM.executeEpochUpdate();
  }

  // 3. setting max deposit for all tokens ✅
  async function setMaxDeposits() {
    const d = config.deployedAddress;
    const d3MM = await ethers.getContractAt("D3MM", d.D3MM);
    const limit1 = BigNumber.from(padZeros(1000, 8));
    const limit2 = BigNumber.from(padZeros(1000, 18));
    const limit3 = BigNumber.from(padZeros(1000, 18));
    const limit4 = BigNumber.from(padZeros(1000000000, 18));
    await d3MM.setMaxDeposit(d.wbtcAddress, limit1);
    //await d3MM.setMaxDeposit(d.wethAddress, limit2);
    await d3MM.setMaxDeposit(d.daiAddress, limit3);
    await d3MM.setMaxDeposit(d.dodoAddress, limit4);
  }

  // 4. owner deposit ✅
  async function ownerDeposit(tokenAddr: string, amount: number, decimals: number) {
    const d3MM = await ethers.getContractAt("D3MM", d.D3MM);
    const token = await ethers.getContractAt("MockERC20", tokenAddr);
    const name = await token.name();
    console.log('name:', name);
    await token.mint(d.D3MM, BigNumber.from(padZeros(amount, decimals)));
    await sleep(10);
    await d3MM.ownerDeposit(tokenAddr);
  }

  async function ownerDepositAllTokens() {
    await ownerDeposit(d.wbtcAddress, 10, 8);
    await ownerDeposit(d.daiAddress, 300, 18);
    await ownerDeposit(d.dodoAddress, 400, 18);
  }

  // 5. user deposit ✅
  async function userDeposit(lp: string, tokenAddr: string, amount: number, decimals: number) {
    const d3MM = await ethers.getContractAt("D3MM", d.D3MM);
    const token = await ethers.getContractAt("MockERC20", tokenAddr);
    const name = await token.name();
    console.log('name:', name);
    await token.mint(d.D3MM, BigNumber.from(padZeros(amount, decimals)));
    await d3MM.lpDeposit(lp, tokenAddr);
  }

  async function userDepositAllTokens() {
    await userDeposit(deployer, d.wbtcAddress, 60, 8);
    await userDeposit(deployer, d.daiAddress, 3000, 18);
    await userDeposit(deployer, d.dodoAddress, 400, 18);
  }

  // 6. add liquidator
  async function addLiquidator(account: string) {
    const d3MM = await ethers.getContractAt("D3MM", d.D3MM);
    const d3Factory = await ethers.getContractAt("D3MMFactory", d.D3MMFactory);
    await d3Factory.addLiquidator(account);
  }

  async function getPoolInfo() {
    const d3MM = await ethers.getContractAt("D3MM", d.D3MM);

    const info = await d3MM.getD3MMInfo();
    console.log(info)
    const oracleAddr = info.oracle;
    const oracle = await ethers.getContractAt("D3Oracle", oracleAddr);

    const poolStatus = await d3MM.getStatus();
    console.log('\npool status:', poolStatus, '\n');
    const ratio = await d3MM.getCollateralRatio();
    console.log(`collateral ratio: ${formatPrice(ratio, 16, 4)}%`);
    const totalAssetValue = await d3MM.getTotalAssetsValue();
    console.log(`total asset value: ${totalAssetValue.div(ONE)}`)
    const totalDebtValue = await d3MM.getTotalDebtValue();
    console.log(`total debt value: ${totalDebtValue.div(ONE)}`)

    const tokenList = await d3MM.getTokenList();
    for (let i = 0; i < tokenList.length; i++) {
      const token = tokenList[i];
      const Token = await ethers.getContractAt("MockERC20", token);
      const symbol = await Token.symbol();
      const decimals = await Token.decimals();

      console.log(`\n========== ${symbol} ==========\n`)
      console.log(`${symbol}: ${token}`)
      console.log('decimals:', decimals);

      const reserve: BigNumber = await d3MM.getTokenReserve(token);
      console.log(`${symbol} reserve: ${removeDecimals(reserve, decimals)}`)
      const balance: BigNumber = await Token.balanceOf(d.D3MM);
      console.log(`${symbol} balance: ${removeDecimals(balance, decimals)}`);

      const assetInfo = await d3MM.getAssetInfo(token);
      console.log("\n[Asset Info]")
      console.log(`D3Token: ${assetInfo.d3Token}`)
      console.log(`reserve: ${removeDecimals(assetInfo.reserve, decimals)}`)
      console.log(`maxDeposit: ${removeDecimals(assetInfo.maxDepositAmount, decimals)}`)
      console.log(`accruedInterest: ${formatPrice(assetInfo.accruedInterest, 16, 2)}%`)

      console.log(`\n[D3Token Info]`)
      const d3Token = await ethers.getContractAt("D3Token", assetInfo.d3Token)
      const d3TokenSymbol = await d3Token.symbol();
      console.log(d3TokenSymbol);
      const d3TokenSupply = await d3Token.totalSupply();
      console.log(`totol supply: ${removeDecimals(d3TokenSupply, decimals)}`);
      const d3TokenWorthOriginAmount = d3TokenSupply.mul(assetInfo.accruedInterest).div(ONE).div(ONE);
      console.log(`worth origin amount: ${d3TokenWorthOriginAmount}`)

      const interestRate = await d3MM.getInterestRate(token)
      console.log("\n")
      console.log(`interest rate: ${formatPrice(interestRate, 16, 2)}%`)
      const price = await oracle.getPrice(token);
      const correction = BigNumber.from(padZeros(1, 18 - decimals)) // some token's decimals not 18
      console.log(`price: ${formatPrice(price.div(correction), 18, 4)}`);
    }
  }

  function formatPrice(price: BigNumber, decimals: number, keepDecimals: number) {
    const a = price.div(BigNumber.from(padZeros(1, decimals - keepDecimals))).toString();
    let b = a.slice(0, -keepDecimals) + "." + a.slice(-keepDecimals);
    if (b.startsWith(".")) {
      b = "0" + b;
    }
    return b;
  }

  function removeDecimals(bn: BigNumber, decimals: number) {
    return bn.div(BigNumber.from(padZeros(1, decimals)));
  }
  
  function padZeros(origin: number, count: number) {
    return origin.toString() + '0'.repeat(count);
  }

  function sleep(s) {
    return new Promise(resolve => setTimeout(resolve, s * 1000));
  }
};

export default func;
func.tags = ["set d3MM"];
