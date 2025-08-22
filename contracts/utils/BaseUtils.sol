// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title BaseUtils
 * @dev Utility library for Base blockchain specific operations
 * @author Base Ecosystem Contributors
 */
library BaseUtils {
    
    // Base mainnet chain ID
    uint256 public constant BASE_CHAIN_ID = 8453;
    
    // Base testnet (Sepolia) chain ID
    uint256 public constant BASE_SEPOLIA_CHAIN_ID = 84532;
    
    // Base L1 gas oracle address
    address public constant L1_GAS_ORACLE = 0x420000000000000000000000000000000000000F;
    
    // Base fee vault address
    address public constant BASE_FEE_VAULT = 0x4200000000000000000000000000000000000019;
    
    // Base L1 block address
    address public constant L1_BLOCK = 0x4200000000000000000000000000000000000015;
    
    /**
     * @dev Check if current chain is Base mainnet
     * @return bool true if on Base mainnet
     */
    function isBaseMainnet() internal view returns (bool) {
        return block.chainid == BASE_CHAIN_ID;
    }
    
    /**
     * @dev Check if current chain is Base testnet
     * @return bool true if on Base testnet
     */
    function isBaseTestnet() internal view returns (bool) {
        return block.chainid == BASE_SEPOLIA_CHAIN_ID;
    }
    
    /**
     * @dev Check if current chain is any Base network
     * @return bool true if on any Base network
     */
    function isBaseNetwork() internal view returns (bool) {
        return isBaseMainnet() || isBaseTestnet();
    }
    
    /**
     * @dev Get the current Base network name
     * @return string network name
     */
    function getNetworkName() internal view returns (string memory) {
        if (isBaseMainnet()) {
            return "Base Mainnet";
        } else if (isBaseTestnet()) {
            return "Base Sepolia";
        } else {
            return "Unknown Network";
        }
    }
    
    /**
     * @dev Calculate L1 gas cost for Base transactions
     * @param data Transaction data
     * @return uint256 L1 gas cost in wei
     */
    function calculateL1GasCost(bytes memory data) internal view returns (uint256) {
        if (!isBaseNetwork()) {
            return 0;
        }
        
        // Simplified L1 gas calculation for Base
        // In production, this would call the L1 gas oracle
        uint256 dataLength = data.length;
        uint256 zeroBytes = 0;
        uint256 nonZeroBytes = 0;
        
        for (uint256 i = 0; i < dataLength; i++) {
            if (data[i] == 0) {
                zeroBytes++;
            } else {
                nonZeroBytes++;
            }
        }
        
        // Base L1 gas calculation: 4 gas per zero byte, 16 gas per non-zero byte
        return (zeroBytes * 4) + (nonZeroBytes * 16);
    }
    
    /**
     * @dev Get Base-optimized gas limit for common operations
     * @param operationType Type of operation (0: transfer, 1: contract call, 2: contract deploy)
     * @return uint256 recommended gas limit
     */
    function getOptimizedGasLimit(uint8 operationType) internal pure returns (uint256) {
        if (operationType == 0) {
            return 21000; // ETH transfer
        } else if (operationType == 1) {
            return 100000; // Contract call
        } else if (operationType == 2) {
            return 2000000; // Contract deployment
        } else {
            return 50000; // Default
        }
    }
    
    /**
     * @dev Check if address is a Base system contract
     * @param addr Address to check
     * @return bool true if system contract
     */
    function isSystemContract(address addr) internal pure returns (bool) {
        return addr == L1_GAS_ORACLE || 
               addr == BASE_FEE_VAULT || 
               addr == L1_BLOCK ||
               (addr >= address(0x4200000000000000000000000000000000000000) && 
                addr <= address(0x42000000000000000000000000000000000000FF));
    }
    
    /**
     * @dev Generate Base-specific transaction hash
     * @param to Recipient address
     * @param value Transaction value
     * @param data Transaction data
     * @param nonce Transaction nonce
     * @return bytes32 transaction hash
     */
    function generateTxHash(
        address to,
        uint256 value,
        bytes memory data,
        uint256 nonce
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                block.chainid,
                msg.sender,
                to,
                value,
                data,
                nonce,
                block.timestamp
            )
        );
    }
    
    /**
     * @dev Validate Base address format
     * @param addr Address to validate
     * @return bool true if valid Base address
     */
    function isValidBaseAddress(address addr) internal pure returns (bool) {
        return addr != address(0) && addr != address(0xdead);
    }
    
    /**
     * @dev Get Base block explorer URL for address
     * @param addr Address to get URL for
     * @return string block explorer URL
     */
    function getExplorerUrl(address addr) internal view returns (string memory) {
        if (isBaseMainnet()) {
            return string(abi.encodePacked("https://basescan.org/address/", toHexString(addr)));
        } else if (isBaseTestnet()) {
            return string(abi.encodePacked("https://sepolia.basescan.org/address/", toHexString(addr)));
        } else {
            return "";
        }
    }
    
    /**
     * @dev Convert address to hex string
     * @param addr Address to convert
     * @return string hex representation
     */
    function toHexString(address addr) internal pure returns (string memory) {
        bytes memory buffer = new bytes(42);
        buffer[0] = '0';
        buffer[1] = 'x';
        for (uint256 i = 0; i < 20; i++) {
            uint8 byteValue = uint8(uint160(addr) >> (8 * (19 - i)));
            buffer[2 + i * 2] = bytes1(byteValue >> 4 < 10 ? 
                byteValue >> 4 + 48 : byteValue >> 4 + 87);
            buffer[3 + i * 2] = bytes1(byteValue & 0x0f < 10 ? 
                byteValue & 0x0f + 48 : byteValue & 0x0f + 87);
        }
        return string(buffer);
    }
}
