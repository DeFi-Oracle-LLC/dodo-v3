import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { GOERLI_CONFIG as config } from "../../config/goerli-config";
import { BigNumber } from "@ethersproject/bignumber";
import { ConstructorFragment } from "ethers/lib/utils";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, ethers } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // await deployDODOChainlinkMock3();
  // await deployWBTCChainlinkMock3();
  // await deployD3Proxy();

  async function deployD3Proxy() {
    let wethAddress = config.defaultAddress["wethAddress"];
    let dodoApproveProxy = config.defaultAddress["DODOApproveProxy"];
    let factoryAddress = config.deployedAddress["D3MMFactory"]

    //const d3ProxyAddress = await deployContract("D3Proxy", "D3Proxy", [dodoApproveProxy, wethAddress, factoryAddress]);
    //console.log("deployed D3Proxy at:", d3ProxyAddress);
    const d3ProxyAddress = config.deployedAddress.D3Proxy;
    await verifyContract(d3ProxyAddress, [dodoApproveProxy, wethAddress, factoryAddress]);
  }

  async function deployDODOChainlinkMock3() {
    const priceFeedAddr = await deployContract("dodoPriceFeedWithOwner", "MockChainlinkPriceFeed3", ["DODO/USD", 8]);
    console.log("deployed DODO price feed with owner at:", priceFeedAddr);
    await verifyContract(priceFeedAddr, ["DODO/USD", 8]);
  }

  async function deployWBTCChainlinkMock3() {
    const priceFeedAddr = await deployContract("wbtcPriceFeedWithOwner", "MockChainlinkPriceFeed3", ["WBTC/USD", 8]);
    console.log("deployed WBTC price feed with owner at:", priceFeedAddr);
    await verifyContract(priceFeedAddr, ["WBTC/USD", 8]);
  }

  async function deployDAIChainlinkMock3() {
    const priceFeedAddr = await deployContract("daiPriceFeedWithOwner", "MockChainlinkPriceFeed3", ["DAI/USD", 8]);
    console.log("deployed DAI price feed with owner at:", priceFeedAddr);
    await verifyContract(priceFeedAddr, ["DAI/USD", 8]);
  }

  async function deployContract(name: string, contract: string, args: any[]) {
    if (!config.deployedAddress[name]) {
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

  async function verifyContract(address: string, args: any[]) {
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
}

export default func;
func.tags = ["D3Proxy"];