import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { GOERLI_CONFIG as config } from "../../config/goerli-config";
import { BigNumber } from "@ethersproject/bignumber";
import * as dotenv from 'dotenv';
dotenv.config();

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, ethers } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // await deployTokens();
  // await deployOracle();
  // await deployRouter();
  // await deployLiquidationRouter();
  // await deployD3MMTemplate();
  // await deployD3TokenTemplate();
  // await deployCloneFactory();
  // await depolyD3MMFactory();
  // await createD3MM();
  // await setD3Logic();
  // await setD3Oracle();
  // await addDODO();
  // await verifyD3Factory()
  // await deployUserQuota()
  // await verifyContract(config.deployedAddress.D3MMFactory)

  async function verifyD3Factory() {
    const d3Template = config.deployedAddress.D3MMTemplate;
    const d3TokenTemplate = config.deployedAddress.D3TokenTemplate;
    const cloneFactory = config.deployedAddress.CloneFactory;
    const maintainer = config.deployedAddress.Maintainer;
    const feeModel = config.deployedAddress.FeeRateModel;
    const args = [d3Template, d3TokenTemplate, cloneFactory, maintainer, feeModel];
    await verifyContract(config.deployedAddress.D3MMFactory, args);
  }

  async function deployContract(name: string, contract: string, args: any[]) {
    if (!config.deployedAddress[name] || config.deployedAddress[name] == "") {
      const deployResult = await deploy(contract, {
        from: deployer,
        args: args,
        log: true,
      });
      return deployResult.address;
    } else {
      return config.deployedAddress[name];
    }
  }

  async function verifyContract(address: string, args?: any[]) {
    if (typeof args == 'undefined') {
      args = []
    }
    try {
      await hre.run("verify:verify", {
        address: address,
        constructorArguments: args,
      });
    } catch (e) {
      if (e.message != "Contract source code already verified") {
        throw(e)
      }
      console.log(e.message)
    }
  }

  async function deployTokens() {
    await deployContract("wbtcAddress", "MockERC20", ["Wrapped BTC", "WBTC", 8]);
    await deployContract("wethAddress", "WETH9", []);
    await deployContract("daiAddress", "MockERC20", ["Dai Stablecoin", "DAI", 18]);
  }

  async function deployOracle() {
    const oracleAddress = await deployContract("D3Oracle", "D3Oracle", []);
    await verifyContract(oracleAddress, [])
    const D3Oracle = await ethers.getContractAt("D3Oracle", oracleAddress);
    sleep(10)
    const priceSourceBTC = {
      oracle: config.chainlinkPriceFeed.BTCUSD,
      isWhitelisted: true,
      priceTolerance: BigNumber.from(padZeros(9, 17)),
      priceDecimal: 8,
      tokenDecimal: 8
    }
    console.log("setPrciceSource for WBTC...")
    await D3Oracle.setPriceSource(config.deployedAddress.wbtcAddress, priceSourceBTC);
    sleep(10)
    const priceSourceETH = {
      oracle: config.chainlinkPriceFeed.ETHUSD,
      isWhitelisted: true,
      priceTolerance: BigNumber.from(padZeros(9, 17)),
      priceDecimal: 8,
      tokenDecimal: 18
    }
    console.log("setPrciceSource for WETH...")
    await D3Oracle.setPriceSource(config.deployedAddress.wethAddress, priceSourceETH);
    sleep(10)
    const priceSourceDAI = {
      oracle: config.chainlinkPriceFeed.DAIUSD,
      isWhitelisted: true,
      priceTolerance: BigNumber.from(padZeros(9, 17)),
      priceDecimal: 8,
      tokenDecimal: 18
    }
    console.log("setPrciceSource for DAI...")
    await D3Oracle.setPriceSource(config.deployedAddress.daiAddress, priceSourceDAI);
    sleep(10)
    const priceSourceDODO = {
      oracle: config.chainlinkPriceFeed.DODOUSD,
      isWhitelisted: true,
      priceTolerance: BigNumber.from(padZeros(9, 17)),
      priceDecimal: 8,
      tokenDecimal: 18
    }
    console.log("setPrciceSource for DODO...")
    await D3Oracle.setPriceSource(config.deployedAddress.dodoAddress, priceSourceDODO);
  }

  async function deployRouter() {
    const oracleAddress = config.deployedAddress.D3Oracle;
    const routerAddress = await deployContract("MockRouter", "MockRouter", [oracleAddress]);
    await verifyContract(routerAddress, [oracleAddress]);
  }

  async function deployLiquidationRouter() {
    await deployContract("D3MMLiquidationRouter", "D3MMLiquidationRouter", []);
  }

  async function deployUserQuota() {
    await deployContract("UserQuotaV3", "UserQuotaV3", []);
  }

  async function deployD3MMTemplate() {
    const fundingLibraryAddress = await deployContract("FundingLibrary", "FundingLibrary", []);
    const liquidationLibraryAddress = await deployContract("LiquidationLibrary", "LiquidationLibrary", []);
    const pmmRangeOrderLibraryAddress = await deployContract("PMMRangeOrderLibrary","PMMRangeOrder",[]);
    const tradingLibraryAddress = await deployContract("TradingLibrary", "TradingLibrary", []);
    await verifyContract(tradingLibraryAddress, []);
    if (!config.deployedAddress["D3MMTemplate"] || config.deployedAddress["D3MMTemplate"] == "") {
      const deployResult = await deploy("D3MM", {
        from: deployer,
        args: [],
        log: true,
        libraries: {
          "FundingLibrary": fundingLibraryAddress,
          "LiquidationLibrary": liquidationLibraryAddress,
          "PMMRangeOrder": pmmRangeOrderLibraryAddress,
          "TradingLibrary": tradingLibraryAddress
        }
      });
      await verifyContract(deployResult.address, []);
      return deployResult.address;
    } else {
      await verifyContract(config.deployedAddress["D3MMTemplate"], []);
      return config.deployedAddress["D3MMTemplate"];
    }
  }

  async function deployD3TokenTemplate() {
    await deployContract("D3TokenTemplate", "D3Token", []);
  }

  async function deployCloneFactory() {
    await deployContract("CloneFactory", "CloneFactory", []);
  }

  async function depolyD3MMFactory() {
    const d3Template = config.deployedAddress.D3MMTemplate;
    const d3TokenTemplate = config.deployedAddress.D3TokenTemplate;
    const cloneFactory = config.deployedAddress.CloneFactory;
    const maintainer = config.deployedAddress.Maintainer;
    const feeModel = config.deployedAddress.FeeRateModel;
    const liquidator1 = process.env.liquidator1;
    const liquidator2 = process.env.liquidator2;

    const args = [d3Template, d3TokenTemplate, cloneFactory, maintainer, feeModel];
    const address = await deployContract("D3MMFactory", "D3MMFactory", args);
    const d3MMFactory = await ethers.getContractAt("D3MMFactory", address);
    await sleep(10);
    await d3MMFactory.addLiquidator(deployer);
    await sleep(10);
    await d3MMFactory.addLiquidator(liquidator1);
    await sleep(10);
    await d3MMFactory.addLiquidator(liquidator2);
    await sleep(10);
    await d3MMFactory.addRouter(config.deployedAddress.D3MMLiquidationRouter);
    await sleep(10);
    await d3MMFactory.setOracle(config.deployedAddress.D3Oracle);
  }

  async function setD3Logic() {
    const d3MMFactory = await ethers.getContractAt("D3MMFactory", config.deployedAddress.D3MMFactory);
    console.log('old template:', await d3MMFactory._D3_LOGIC_());
    console.log('setting new template...');
    await d3MMFactory.setD3Logic(config.deployedAddress.D3MMTemplate);
  }

  async function setD3Oracle() {
    const d3MMFactory = await ethers.getContractAt("D3MMFactory", config.deployedAddress.D3MMFactory);
    console.log('old oracle:', await d3MMFactory._ORACLE_());
    console.log('setting new oracle...');
    await d3MMFactory.setOracle(config.deployedAddress.D3Oracle);
  }

  async function createD3MM() {
    const d = config.deployedAddress;
    const d3MMFactory = await ethers.getContractAt("D3MMFactory", config.deployedAddress.D3MMFactory);
    const d3MM = await d3MMFactory.breedDODO(
      deployer,
      [d.wbtcAddress, d.wethAddress, d.daiAddress, d.dodoAddress],
      Math.floor(Date.now() / 1000) - 3600 * 11,
      86400, // epoch duration 1 day
      BigNumber.from(padZeros(4, 17)), // 4e17
      BigNumber.from(padZeros(38, 16)), // 38%
    )
    console.log("new D3MM:", d3MM);
  }

  async function addDODO() {
    // 1. create new token: DODO
    const dodoAddr = await deployContract("dodoAddress", "MockERC20", ["DODO bird", "DODO", 18]);
    console.log("deployed DODO at:", dodoAddr);

    // 2. create a price feed for DODO, of which the price will fluctuate wildly over time
    const priceFeedAddr = await deployContract("dodoPriceFeed", "MockChainlinkPriceFeed2", ["DODO/USD", 8]);
    console.log("deployed DODO price feed at:", priceFeedAddr);
    await verifyContract(priceFeedAddr, ["DODO/USD", 8]);

    // 3. add new price feed to oracle
    const oracle = await ethers.getContractAt("D3Oracle", config.deployedAddress.D3Oracle);
    const priceSourceDODO = {
      oracle: priceFeedAddr,
      isWhitelisted: true,
      priceTolerance: 1,
      priceDecimal: 8
    }
    await oracle.setPriceSource(config.deployedAddress.dodoAddress, priceSourceDODO);
    console.log("set DODO price source success!")

    // 4. add DODO to d3MM
    const d3MM = await ethers.getContractAt("D3MM", config.deployedAddress.D3MM);
    await d3MM.addNewToken(dodoAddr, BigNumber.from("200000000000000000"), BigNumber.from("1000000000000000000000"));
    console.log("added new token:", dodoAddr);
  }

  // ---------- helper function ----------

  function padZeros(origin: number, count: number) {
    return origin.toString() + '0'.repeat(count);
  }

  function sleep(s) {
    return new Promise(resolve => setTimeout(resolve, s * 1000));
  }
};

export default func;
func.tags = ["MockERC20"];
