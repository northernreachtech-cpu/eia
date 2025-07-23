import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { User, Building, FileText, Loader2, CheckCircle } from "lucide-react";
import {
  useCurrentAccount,
  useSignAndExecuteTransaction,
} from "@mysten/dapp-kit";
import { useAriyaSDK } from "../lib/sdk";
import Button from "../components/Button";
import Card from "../components/Card";
import { suiClient } from "../config/sui";

const CreateOrganizerProfile = () => {
  const [formData, setFormData] = useState({
    name: "",
    bio: "",
  });
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [success, setSuccess] = useState(false);
  const [error, setError] = useState("");
  const [_hasProfile, setHasProfile] = useState<boolean | null>(null);
  const [isChecking, setIsChecking] = useState(true);

  const navigate = useNavigate();
  const currentAccount = useCurrentAccount();
  const sdk = useAriyaSDK();
  const { mutate: signAndExecute } = useSignAndExecuteTransaction();

  // Check if user already has a profile
  useEffect(() => {
    const checkProfile = async () => {
      if (!currentAccount) {
        setHasProfile(null);
        setIsChecking(false);
        return;
      }

      setIsChecking(true);
      try {
        const exists = await sdk.eventManagement.hasOrganizerProfile(
          currentAccount.address
        );
        setHasProfile(exists);
        if (exists) {
          // If they have a profile, redirect to dashboard
          navigate("/dashboard/organizer");
        }
      } catch (error) {
        console.error("Error checking profile:", error);
        setError("Failed to check existing profile");
      }
      setIsChecking(false);
    };

    checkProfile();
  }, [currentAccount, navigate, sdk.eventManagement]);

  const handleInputChange = (
    e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>
  ) => {
    const { name, value } = e.target;
    setFormData((prev) => ({
      ...prev,
      [name]: value,
    }));
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!currentAccount) {
      setError("Please connect your wallet first");
      return;
    }

    if (!formData.name.trim() || !formData.bio.trim()) {
      setError("Please fill in all fields");
      return;
    }

    setIsSubmitting(true);
    setError("");

    try {
      // Create the transaction for organizer profile creation
      const tx = sdk.eventManagement.createOrganizerProfile(
        formData.name.trim(),
        formData.bio.trim(),
        currentAccount.address
      );

      // Sign and execute the transaction
      signAndExecute(
        { transaction: tx },
        {
          onSuccess: async (result) => {
            console.log("Organizer profile created successfully:", result);

            // --- Transaction Effects Debugging ---
            console.log("--- Waiting for transaction to be indexed... ---");
            try {
              // Wait for the transaction to be finalized
              await suiClient.waitForTransaction({
                digest: result.digest,
              });

              const fullTx = await suiClient.getTransactionBlock({
                digest: result.digest,
                options: {
                  showObjectChanges: true,
                },
              });

              console.log("--- Inspecting Transaction Effects ---", fullTx);
              if (fullTx.objectChanges) {
                const createdObjects = fullTx.objectChanges.filter(
                  (change) => change.type === "created"
                );
                console.log(`Found ${createdObjects.length} created objects.`);
                createdObjects.forEach((change, index) => {
                  if (change.type === "created") {
                    console.log(`[Object ${index + 1}]`);
                    console.log(`  ID: ${change.objectId}`);
                    console.log(`  Owner: ${JSON.stringify(change.owner)}`);
                  }
                });
              } else {
                console.log(
                  "No 'objectChanges' found in full transaction details."
                );
              }
            } catch (txError) {
              console.error(
                "Failed to fetch full transaction details:",
                txError
              );
            }
            console.log("------------------------------------");
            // --- End Debugging ---

            setSuccess(true);
            setTimeout(() => {
              navigate("/dashboard/organizer");
            }, 2000);
          },
          onError: (error) => {
            console.error("Error creating organizer profile:", error);
            setError("Failed to create organizer profile. Please try again.");
            setIsSubmitting(false);
          },
        }
      );
    } catch (error) {
      console.error("Error creating organizer profile:", error);
      setError("Failed to create organizer profile. Please try again.");
      setIsSubmitting(false);
    }
  };

  if (!currentAccount) {
    return (
      <div className="min-h-screen pt-24 px-4 sm:px-6 lg:px-8">
        <div className="max-w-2xl mx-auto">
          <Card className="p-8 text-center">
            <div className="w-16 h-16 bg-primary/10 rounded-full flex items-center justify-center mx-auto mb-4">
              <User className="h-8 w-8 text-primary" />
            </div>
            <h2 className="text-2xl font-bold text-white mb-2">
              Connect Your Wallet
            </h2>
            <p className="text-white/60 mb-6">
              You need to connect your wallet to create an organizer profile
            </p>
            <Button onClick={() => navigate("/")} variant="outline">
              Go Back to Home
            </Button>
          </Card>
        </div>
      </div>
    );
  }

  if (isChecking) {
    return (
      <div className="min-h-screen pt-24 px-4 sm:px-6 lg:px-8">
        <div className="max-w-2xl mx-auto">
          <Card className="p-8 text-center">
            <div className="flex items-center justify-center">
              <Loader2 className="h-8 w-8 animate-spin text-primary" />
            </div>
            <h2 className="text-2xl font-bold text-white mt-4">
              Checking Profile Status
            </h2>
            <p className="text-white/60 mt-2">
              Please wait while we check your profile status...
            </p>
          </Card>
        </div>
      </div>
    );
  }

  if (success) {
    return (
      <div className="min-h-screen pt-24 px-4 sm:px-6 lg:px-8">
        <div className="max-w-2xl mx-auto">
          <Card className="p-8 text-center">
            <div className="w-16 h-16 bg-green-500/10 rounded-full flex items-center justify-center mx-auto mb-4">
              <CheckCircle className="h-8 w-8 text-green-500" />
            </div>
            <h2 className="text-2xl font-bold text-white mb-2">
              Profile Created Successfully!
            </h2>
            <p className="text-white/60 mb-6">
              Your organizer profile has been created on the blockchain.
              Redirecting to your dashboard...
            </p>
            <div className="flex items-center justify-center">
              <Loader2 className="h-5 w-5 animate-spin text-primary" />
            </div>
          </Card>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen pt-24 px-4 sm:px-6 lg:px-8">
      <div className="max-w-2xl mx-auto">
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-white mb-2">
            Create Organizer Profile
          </h1>
          <p className="text-white/60">
            Set up your organizer profile to start creating and managing events
            on the EIA Protocol
          </p>
        </div>

        <Card className="p-8">
          <form onSubmit={handleSubmit} className="space-y-6">
            {/* Name Field */}
            <div>
              <label className="block text-sm font-medium text-white mb-2">
                <User className="inline h-4 w-4 mr-2" />
                Organizer Name
              </label>
              <input
                type="text"
                name="name"
                value={formData.name}
                onChange={handleInputChange}
                placeholder="Enter your name or organization name"
                className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-lg text-white placeholder-white/40 focus:outline-none focus:ring-2 focus:ring-primary/50 focus:border-primary/50 transition-all"
                disabled={isSubmitting}
                required
              />
            </div>

            {/* Bio Field */}
            <div>
              <label className="block text-sm font-medium text-white mb-2">
                <FileText className="inline h-4 w-4 mr-2" />
                Bio
              </label>
              <textarea
                name="bio"
                value={formData.bio}
                onChange={handleInputChange}
                placeholder="Tell us about yourself and your experience organizing events..."
                rows={4}
                className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-lg text-white placeholder-white/40 focus:outline-none focus:ring-2 focus:ring-primary/50 focus:border-primary/50 transition-all resize-none"
                disabled={isSubmitting}
                required
              />
            </div>

            {/* Connected Wallet Info */}
            <div className="p-4 bg-white/5 border border-white/10 rounded-lg">
              <div className="flex items-center justify-between">
                <div>
                  <div className="text-sm font-medium text-white">
                    Connected Wallet
                  </div>
                  <div className="text-xs text-white/60 font-mono">
                    {currentAccount.address.slice(0, 8)}...
                    {currentAccount.address.slice(-8)}
                  </div>
                </div>
                <div className="w-2 h-2 bg-green-500 rounded-full"></div>
              </div>
            </div>

            {/* Error Message */}
            {error && (
              <div className="p-4 bg-red-500/10 border border-red-500/20 rounded-lg">
                <p className="text-red-400 text-sm">{error}</p>
              </div>
            )}

            {/* Submit Button */}
            <Button
              type="submit"
              className="w-full"
              disabled={
                isSubmitting || !formData.name.trim() || !formData.bio.trim()
              }
            >
              {isSubmitting ? (
                <>
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  Creating Profile...
                </>
              ) : (
                <>
                  <Building className="mr-2 h-4 w-4" />
                  Create Organizer Profile
                </>
              )}
            </Button>

            {/* Info Box */}
            <div className="p-4 bg-blue-500/10 border border-blue-500/20 rounded-lg">
              <p className="text-blue-400 text-sm">
                <strong>Note:</strong> Creating an organizer profile requires a
                blockchain transaction. This will establish your identity on the
                EIA Protocol and allow you to create events.
              </p>
            </div>
          </form>
        </Card>
      </div>
    </div>
  );
};

export default CreateOrganizerProfile;
