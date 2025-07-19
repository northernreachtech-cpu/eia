import { getFullnodeUrl, SuiClient } from "@mysten/sui/client";
import { createNetworkConfig } from "@mysten/dapp-kit";

const { networkConfig, useNetworkVariable, useNetworkVariables } =
  createNetworkConfig({
    devnet: {
      url: getFullnodeUrl("devnet"),
      variables: {
        packageId: "0x0", // Replace with actual package ID after deployment
        escrowRegistryId:
          "0x07bb557f4522dca6628656e410a92ebdae129a843dae164b589a6972934e3b0c",
        communityRegistryId:
          "0x0bc6254162f07f939bc56dadf590c6be1e1043b68ed7ed9a8f4b455920e0b7a5",
        registrationRegistryId:
          "0x0e0e241992af8e6975f8e5438c760d8ae731b14a0d6fd6f90f3ee8a530c1e9a7",
        eventRegistryId:
          "0x5825ea995c3b21b57d37fac51a8a15e568c708eb68b63761cc0dcfccbde457ee",
        airdropRegistryId:
          "0x5cf1b339d6b56871af9c3bc2aff869831d36bcf1f7c8cf645103550471aa06f4",
        nftRegistryId:
          "0x783e7665be393169e1f9fc6827f466be4177efbc0656678987718cf0844c18fb",
        attendanceRegistryId:
          "0x932cabd3104fa6ae708cdf98fd7f66d08518cf6eb46369808efc9bca5aaa1dfc",
        ratingRegistryId:
          "0xedecb25017813b8f197abf3d605fa1ebc929c92cbac8fc174661d03a6384ecd1",
      },
    },
    testnet: {
      url: getFullnodeUrl("testnet"),
      variables: {
        packageId:
          "0x10d0fc6df7becc7661d35431ae0e0938dd78c429eb2c52eb370c78f2fb775af4",
        escrowRegistryId:
          "0x07bb557f4522dca6628656e410a92ebdae129a843dae164b589a6972934e3b0c",
        communityRegistryId:
          "0x0bc6254162f07f939bc56dadf590c6be1e1043b68ed7ed9a8f4b455920e0b7a5",
        registrationRegistryId:
          "0x0e0e241992af8e6975f8e5438c760d8ae731b14a0d6fd6f90f3ee8a530c1e9a7",
        eventRegistryId:
          "0x5825ea995c3b21b57d37fac51a8a15e568c708eb68b63761cc0dcfccbde457ee",
        airdropRegistryId:
          "0x5cf1b339d6b56871af9c3bc2aff869831d36bcf1f7c8cf645103550471aa06f4",
        nftRegistryId:
          "0x783e7665be393169e1f9fc6827f466be4177efbc0656678987718cf0844c18fb",
        attendanceRegistryId:
          "0x932cabd3104fa6ae708cdf98fd7f66d08518cf6eb46369808efc9bca5aaa1dfc",
        ratingRegistryId:
          "0xedecb25017813b8f197abf3d605fa1ebc929c92cbac8fc174661d03a6384ecd1",
      },
    },
    mainnet: {
      url: getFullnodeUrl("mainnet"),
      variables: {
        packageId: "0x0", // Replace with actual package ID after deployment
        escrowRegistryId:
          "0x07bb557f4522dca6628656e410a92ebdae129a843dae164b589a6972934e3b0c",
        communityRegistryId:
          "0x0bc6254162f07f939bc56dadf590c6be1e1043b68ed7ed9a8f4b455920e0b7a5",
        registrationRegistryId:
          "0x0e0e241992af8e6975f8e5438c760d8ae731b14a0d6fd6f90f3ee8a530c1e9a7",
        eventRegistryId:
          "0x5825ea995c3b21b57d37fac51a8a15e568c708eb68b63761cc0dcfccbde457ee",
        airdropRegistryId:
          "0x5cf1b339d6b56871af9c3bc2aff869831d36bcf1f7c8cf645103550471aa06f4",
        nftRegistryId:
          "0x783e7665be393169e1f9fc6827f466be4177efbc0656678987718cf0844c18fb",
        attendanceRegistryId:
          "0x932cabd3104fa6ae708cdf98fd7f66d08518cf6eb46369808efc9bca5aaa1dfc",
        ratingRegistryId:
          "0xedecb25017813b8f197abf3d605fa1ebc929c92cbac8fc174661d03a6384ecd1",
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
