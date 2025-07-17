import { SuiClient, getFullnodeUrl } from "@mysten/sui/client";

const PACKAGE_ID =
  "0x10d0fc6df7becc7661d35431ae0e0938dd78c429eb2c52eb370c78f2fb775af4";

async function findEventRegistry() {
  const client = new SuiClient({ url: getFullnodeUrl("testnet") });

  try {
    console.log("Searching for EventRegistry objects...");

    // Method 1: Try to find objects by type using getDynamicFields
    const eventRegistryType = `${PACKAGE_ID}::event_management::EventRegistry`;
    console.log("Looking for type:", eventRegistryType);

    // Method 2: Search in recent transactions for package deployment
    console.log("\nSearching recent transactions...");

    // Get recent transactions (this might help find the deployment)
    const txns = await client.queryTransactionBlocks({
      filter: {
        MoveFunction: {
          package: PACKAGE_ID,
          module: "event_management",
          function: "init",
        },
      },
      options: {
        showEffects: true,
        showEvents: true,
        showObjectChanges: true,
      },
      limit: 10,
    });

    console.log(`Found ${txns.data.length} init transactions`);

    for (const txn of txns.data) {
      console.log(`\nTransaction: ${txn.digest}`);

      if (txn.objectChanges) {
        for (const change of txn.objectChanges) {
          if (
            change.type === "created" &&
            change.objectType?.includes("EventRegistry")
          ) {
            console.log(`Found EventRegistry: ${change.objectId}`);
            return change.objectId;
          }
        }
      }
    }

    // Method 3: If no init transactions found, try to find any objects with the EventRegistry type
    console.log("\nTrying alternative search...");

    // This is a more manual approach - we'll need to provide instructions
    console.log("If automatic search fails, please:");
    console.log("1. Check your package deployment transaction on Sui Explorer");
    console.log("2. Look for 'Object Changes' in the transaction");
    console.log(
      "3. Find the object with type ending in '::event_management::EventRegistry'"
    );
    console.log("4. Copy that object ID");

    return null;
  } catch (error) {
    console.error("Error finding EventRegistry:", error);

    console.log("\nManual steps to find EventRegistry:");
    console.log("1. Go to https://suiscan.xyz/testnet");
    console.log(`2. Search for your package: ${PACKAGE_ID}`);
    console.log("3. Look at the deployment transaction");
    console.log("4. Find the EventRegistry object in 'Object Changes'");

    return null;
  }
}

// Run the script
findEventRegistry().then((registryId) => {
  if (registryId) {
    console.log(`\n✅ Found EventRegistry!`);
    console.log(`Update your config with:`);
    console.log(`eventRegistryId: "${registryId}"`);
  } else {
    console.log(`\n❌ Could not automatically find EventRegistry`);
    console.log(`Please check manually using the steps above`);
  }
});
