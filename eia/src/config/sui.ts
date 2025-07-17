import { getFullnodeUrl, SuiClient } from "@mysten/sui/client";
import { createNetworkConfig } from "@mysten/dapp-kit";

const { networkConfig, useNetworkVariable, useNetworkVariables } =
  createNetworkConfig({
    devnet: {
      url: getFullnodeUrl("devnet"),
      variables: {
        packageId: "0x0", // Replace with actual package ID after deployment
      },
    },
    testnet: {
      url: getFullnodeUrl("testnet"),
      variables: {
        packageId:
          "0x10d0fc6df7becc7661d35431ae0e0938dd78c429eb2c52eb370c78f2fb775af4",
      },
    },
    mainnet: {
      url: getFullnodeUrl("mainnet"),
      variables: {
        packageId: "0x0", // Replace with actual package ID after deployment
      },
    },
  });

export { useNetworkVariable, useNetworkVariables, networkConfig };

// Create Sui client instance
export const suiClient = new SuiClient({
  url: networkConfig.testnet.url, // Default to testnet for development
});

// Constants
export const PASS_VALIDITY_DURATION = 24 * 60 * 60 * 1000; // 24 hours in milliseconds
