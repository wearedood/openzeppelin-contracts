# Base Blockchain Development Tutorial

## Complete Guide to Building on Base with OpenZeppelin Contracts

### Table of Contents
1. [Introduction to Base](#introduction)
2. [Setting Up Your Development Environment](#setup)
3. [Smart Contract Examples](#contracts)
4. [DeFi Integration Patterns](#defi)
5. [Security Best Practices](#security)
6. [Deployment Guide](#deployment)
7. [Testing Strategies](#testing)

## Introduction to Base {#introduction}

Base is Coinbase's secure, low-cost, builder-friendly Ethereum L2 built to bring the next billion users onchain. This tutorial demonstrates how to leverage OpenZeppelin contracts for secure Base development.

### Why Base?
- **Low fees**: Significantly reduced transaction costs
- **EVM compatibility**: Full Ethereum compatibility
- **Coinbase integration**: Seamless fiat onramps
- **Developer tools**: Comprehensive tooling ecosystem

## Setting Up Your Development Environment {#setup}

### Prerequisites
```bash
# Install Node.js and npm
node --version  # v18+
npm --version   # v8+

# Install Hardhat
npm install --save-dev hardhat

# Install OpenZeppelin contracts
npm install @openzeppelin/contracts
```

### Hardhat Configuration for Base
```javascript
// hardhat.config.js
require("@nomicfoundation/hardhat-toolbox");

module.exports = {
  solidity: "0.8.19",
  networks: {
    base: {
      url: "https://mainnet.base.org",
      accounts: [process.env.PRIVATE_KEY],
      chainId: 8453
    },
    baseGoerli: {
      url: "https://goerli.base.org",
      accounts: [process.env.PRIVATE_KEY],
      chainId: 84531
    }
  },
  etherscan: {
    apiKey: {
      base: process.env.BASESCAN_API_KEY
    }
  }
};
```

## Smart Contract Examples {#contracts}

### 1. ERC20 Token with Base Optimizations
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BaseToken is ERC20, ERC20Burnable, Pausable, Ownable {
    uint256 public constant MAX_SUPPLY = 1000000 * 10**18;
    
    constructor() ERC20("BaseToken", "BASE") {
        _mint(msg.sender, 100000 * 10**18);
    }
    
    function mint(address to, uint256 amount) public onlyOwner {
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds max supply");
        _mint(to, amount);
    }
    
    function pause() public onlyOwner {
        _pause();
    }
    
    function unpause() public onlyOwner {
        _unpause();
    }
    
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal whenNotPaused override {
        super._beforeTokenTransfer(from, to, amount);
    }
}
```

### 2. NFT Collection with Base Features
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract BaseNFT is ERC721, ERC721Enumerable, ERC721URIStorage, Pausable, Ownable {
    using Counters for Counters.Counter;
    
    Counters.Counter private _tokenIdCounter;
    uint256 public constant MAX_SUPPLY = 10000;
    uint256 public mintPrice = 0.001 ether; // Low price for Base
    
    constructor() ERC721("BaseNFT", "BNFT") {}
    
    function mint(address to, string memory uri) public payable {
        require(msg.value >= mintPrice, "Insufficient payment");
        require(_tokenIdCounter.current() < MAX_SUPPLY, "Max supply reached");
        
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }
    
    function batchMint(address[] memory recipients, string[] memory uris) 
        public 
        payable 
        onlyOwner 
    {
        require(recipients.length == uris.length, "Arrays length mismatch");
        require(msg.value >= mintPrice * recipients.length, "Insufficient payment");
        
        for (uint256 i = 0; i < recipients.length; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            _safeMint(recipients[i], tokenId);
            _setTokenURI(tokenId, uris[i]);
        }
    }
    
    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        payable(owner()).transfer(balance);
    }
    
    // Override functions for multiple inheritance
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Enumerable) whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }
    
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }
    
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
    
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
```

### 3. DeFi Staking Contract
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract BaseStaking is ReentrancyGuard, Ownable, Pausable {
    using SafeERC20 for IERC20;
    
    IERC20 public stakingToken;
    IERC20 public rewardToken;
    
    uint256 public rewardRate = 100; // 100 tokens per second
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public balances;
    
    uint256 private _totalSupply;
    
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    
    constructor(address _stakingToken, address _rewardToken) {
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
    }
    
    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;
        
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }
    
    function rewardPerToken() public view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored +
            (((block.timestamp - lastUpdateTime) * rewardRate * 1e18) / _totalSupply);
    }
    
    function earned(address account) public view returns (uint256) {
        return
            ((balances[account] * (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18) +
            rewards[account];
    }
    
    function stake(uint256 amount) external nonReentrant whenNotPaused updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");
        _totalSupply += amount;
        balances[msg.sender] += amount;
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }
    
    function withdraw(uint256 amount) public nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        require(balances[msg.sender] >= amount, "Insufficient balance");
        _totalSupply -= amount;
        balances[msg.sender] -= amount;
        stakingToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }
    
    function getReward() public nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardToken.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }
    
    function exit() external {
        withdraw(balances[msg.sender]);
        getReward();
    }
}
```

## DeFi Integration Patterns {#defi}

### Uniswap V3 Integration on Base
```javascript
// scripts/uniswap-integration.js
const { ethers } = require("hardhat");

async function swapTokens() {
    const UNISWAP_V3_ROUTER = "0xE592427A0AEce92De3Edee1F18E0157C05861564";
    const WETH = "0x4200000000000000000000000000000000000006"; // Base WETH
    const USDC = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"; // Base USDC
    
    const router = await ethers.getContractAt("ISwapRouter", UNISWAP_V3_ROUTER);
    
    const params = {
        tokenIn: WETH,
        tokenOut: USDC,
        fee: 3000, // 0.3%
        recipient: await signer.getAddress(),
        deadline: Math.floor(Date.now() / 1000) + 60 * 20, // 20 minutes
        amountIn: ethers.utils.parseEther("0.1"),
        amountOutMinimum: 0,
        sqrtPriceLimitX96: 0,
    };
    
    const tx = await router.exactInputSingle(params);
    await tx.wait();
    console.log("Swap completed:", tx.hash);
}
```

### Compound Integration
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface ICToken {
    function mint(uint256 mintAmount) external returns (uint256);
    function redeem(uint256 redeemTokens) external returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
}

contract BaseCompoundIntegration is ReentrancyGuard {
    IERC20 public usdc;
    ICToken public cUSDC;
    
    constructor(address _usdc, address _cUSDC) {
        usdc = IERC20(_usdc);
        cUSDC = ICToken(_cUSDC);
    }
    
    function supplyUSDC(uint256 amount) external nonReentrant {
        usdc.transferFrom(msg.sender, address(this), amount);
        usdc.approve(address(cUSDC), amount);
        require(cUSDC.mint(amount) == 0, "Mint failed");
    }
    
    function withdrawUSDC(uint256 cTokenAmount) external nonReentrant {
        require(cUSDC.redeem(cTokenAmount) == 0, "Redeem failed");
        uint256 balance = usdc.balanceOf(address(this));
        usdc.transfer(msg.sender, balance);
    }
}
```

## Security Best Practices {#security}

### 1. Access Control Implementation
```solidity
import "@openzeppelin/contracts/access/AccessControl.sol";

contract SecureContract is AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
    }
    
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        // Minting logic
    }
}
```

### 2. Reentrancy Protection
```solidity
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract SecureWithdrawal is ReentrancyGuard {
    mapping(address => uint256) public balances;
    
    function withdraw() external nonReentrant {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "No balance");
        
        balances[msg.sender] = 0; // Update state first
        
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }
}
```

## Deployment Guide {#deployment}

### Deployment Script
```javascript
// scripts/deploy.js
const { ethers } = require("hardhat");

async function main() {
    console.log("Deploying to Base...");
    
    // Deploy BaseToken
    const BaseToken = await ethers.getContractFactory("BaseToken");
    const baseToken = await BaseToken.deploy();
    await baseToken.deployed();
    console.log("BaseToken deployed to:", baseToken.address);
    
    // Deploy BaseNFT
    const BaseNFT = await ethers.getContractFactory("BaseNFT");
    const baseNFT = await BaseNFT.deploy();
    await baseNFT.deployed();
    console.log("BaseNFT deployed to:", baseNFT.address);
    
    // Deploy Staking Contract
    const BaseStaking = await ethers.getContractFactory("BaseStaking");
    const staking = await BaseStaking.deploy(baseToken.address, baseToken.address);
    await staking.deployed();
    console.log("BaseStaking deployed to:", staking.address);
    
    // Verify contracts
    if (network.name !== "hardhat") {
        console.log("Waiting for block confirmations...");
        await baseToken.deployTransaction.wait(6);
        
        await hre.run("verify:verify", {
            address: baseToken.address,
            constructorArguments: [],
        });
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
```

### Environment Setup
```bash
# .env file
PRIVATE_KEY=your_private_key_here
BASESCAN_API_KEY=your_basescan_api_key
ALCHEMY_API_KEY=your_alchemy_api_key

# Deploy to Base testnet
npx hardhat run scripts/deploy.js --network baseGoerli

# Deploy to Base mainnet
npx hardhat run scripts/deploy.js --network base
```

## Testing Strategies {#testing}

### Comprehensive Test Suite
```javascript
// test/BaseToken.test.js
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("BaseToken", function () {
    let baseToken;
    let owner;
    let addr1;
    let addr2;
    
    beforeEach(async function () {
        [owner, addr1, addr2] = await ethers.getSigners();
        
        const BaseToken = await ethers.getContractFactory("BaseToken");
        baseToken = await BaseToken.deploy();
        await baseToken.deployed();
    });
    
    describe("Deployment", function () {
        it("Should set the right owner", async function () {
            expect(await baseToken.owner()).to.equal(owner.address);
        });
        
        it("Should assign the total supply to the owner", async function () {
            const ownerBalance = await baseToken.balanceOf(owner.address);
            expect(await baseToken.totalSupply()).to.equal(ownerBalance);
        });
    });
    
    describe("Minting", function () {
        it("Should mint tokens to specified address", async function () {
            const mintAmount = ethers.utils.parseEther("1000");
            await baseToken.mint(addr1.address, mintAmount);
            
            expect(await baseToken.balanceOf(addr1.address)).to.equal(mintAmount);
        });
        
        it("Should fail if minting exceeds max supply", async function () {
            const maxSupply = await baseToken.MAX_SUPPLY();
            const currentSupply = await baseToken.totalSupply();
            const excessAmount = maxSupply.sub(currentSupply).add(1);
            
            await expect(
                baseToken.mint(addr1.address, excessAmount)
            ).to.be.revertedWith("Exceeds max supply");
        });
    });
    
    describe("Pausable", function () {
        it("Should pause and unpause transfers", async function () {
            await baseToken.pause();
            
            await expect(
                baseToken.transfer(addr1.address, ethers.utils.parseEther("100"))
            ).to.be.revertedWith("Pausable: paused");
            
            await baseToken.unpause();
            
            await expect(
                baseToken.transfer(addr1.address, ethers.utils.parseEther("100"))
            ).to.not.be.reverted;
        });
    });
});
```

### Gas Optimization Tests
```javascript
// test/gas-optimization.test.js
describe("Gas Optimization", function () {
    it("Should use minimal gas for transfers", async function () {
        const tx = await baseToken.transfer(addr1.address, ethers.utils.parseEther("100"));
        const receipt = await tx.wait();
        
        console.log("Transfer gas used:", receipt.gasUsed.toString());
        expect(receipt.gasUsed).to.be.below(60000); // Base L2 optimization
    });
    
    it("Should batch operations efficiently", async function () {
        const recipients = [addr1.address, addr2.address];
        const uris = ["uri1", "uri2"];
        const value = ethers.utils.parseEther("0.002");
        
        const tx = await baseNFT.batchMint(recipients, uris, { value });
        const receipt = await tx.wait();
        
        console.log("Batch mint gas used:", receipt.gasUsed.toString());
        expect(receipt.gasUsed).to.be.below(200000);
    });
});
```

## Advanced Patterns

### Cross-Chain Bridge Integration
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BaseBridgeToken is ERC20, Ownable {
    address public bridge;
    
    modifier onlyBridge() {
        require(msg.sender == bridge, "Only bridge can call");
        _;
    }
    
    constructor(address _bridge) ERC20("BridgeToken", "BRIDGE") {
        bridge = _bridge;
    }
    
    function bridgeMint(address to, uint256 amount) external onlyBridge {
        _mint(to, amount);
    }
    
    function bridgeBurn(address from, uint256 amount) external onlyBridge {
        _burn(from, amount);
    }
}
```

### Oracle Integration
```solidity
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract PriceOracle {
    AggregatorV3Interface internal priceFeed;
    
    constructor() {
        // Base ETH/USD price feed
        priceFeed = AggregatorV3Interface(0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70);
    }
    
    function getLatestPrice() public view returns (int) {
        (, int price, , , ) = priceFeed.latestRoundData();
        return price;
    }
}
```

## Conclusion

This tutorial provides a comprehensive foundation for building secure, efficient applications on Base using OpenZeppelin contracts. The examples demonstrate:

- **Security-first development** with OpenZeppelin's battle-tested contracts
- **Gas optimization** techniques for L2 deployment
- **DeFi integration** patterns for Base ecosystem
- **Testing strategies** for robust applications
- **Deployment best practices** for production readiness

### Next Steps
1. Explore Base-specific DeFi protocols
2. Implement cross-chain functionality
3. Optimize for Base's low-cost environment
4. Build user-friendly dApps with Coinbase integration

### Resources
- [Base Documentation](https://docs.base.org/)
- [OpenZeppelin Documentation](https://docs.openzeppelin.com/)
- [Base Developer Portal](https://base.org/developers)
- [Hardhat Documentation](https://hardhat.org/docs)

---

*This tutorial is maintained by the community. Contributions and improvements are welcome.*
