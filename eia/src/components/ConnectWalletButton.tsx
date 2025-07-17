import { useState, useEffect, useRef } from "react";
import {
  Wallet,
  ChevronDown,
  Copy,
  ExternalLink,
  LogOut,
  X,
} from "lucide-react";
import {
  useCurrentAccount,
  useConnectWallet,
  useDisconnectWallet,
  useWallets,
} from "@mysten/dapp-kit";
import Button from "./Button";
import Card from "./Card";

const ConnectWalletButton = () => {
  const [showDropdown, setShowDropdown] = useState(false);
  const [copiedAddress, setCopiedAddress] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);
  const currentAccount = useCurrentAccount();
  const { mutate: connect } = useConnectWallet();
  const { mutate: disconnect } = useDisconnectWallet();
  const wallets = useWallets();

  const formatAddress = (address: string) => {
    return `${address.slice(0, 6)}...${address.slice(-4)}`;
  };

  const copyToClipboard = async (text: string) => {
    try {
      await navigator.clipboard.writeText(text);
      setCopiedAddress(true);
      setTimeout(() => setCopiedAddress(false), 2000);
    } catch (err) {
      console.error("Failed to copy: ", err);
    }
  };

  const openExplorer = (address: string) => {
    window.open(`https://suiscan.xyz/mainnet/account/${address}`, "_blank");
  };

  // Close dropdown when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (
        dropdownRef.current &&
        !dropdownRef.current.contains(event.target as Node)
      ) {
        setShowDropdown(false);
      }
    };

    document.addEventListener("mousedown", handleClickOutside);
    return () => {
      document.removeEventListener("mousedown", handleClickOutside);
    };
  }, []);

  const handleConnect = (walletName: string) => {
    const wallet = wallets.find((w) => w.name === walletName);
    if (wallet) {
      connect(
        { wallet },
        {
          onSuccess: () => {
            setShowDropdown(false);
          },
        }
      );
    }
  };

  const handleDisconnect = () => {
    disconnect();
    setShowDropdown(false);
  };

  // Get wallet info for display
  const getWalletDisplayInfo = (walletName: string) => {
    switch (walletName) {
      case "Sui Wallet":
        return { icon: "🔵", description: "Official Sui Wallet" };
      case "Suiet":
        return { icon: "💎", description: "Suiet Wallet" };
      case "Martian Sui Wallet":
        return { icon: "🚀", description: "Martian Wallet" };
      case "Ethos Wallet":
        return { icon: "⚡", description: "Ethos Wallet" };
      default:
        return { icon: "💳", description: "Sui Wallet" };
    }
  };

  if (!currentAccount) {
    return (
      <div className="relative" ref={dropdownRef}>
        <Button 
          variant="outline" 
          onClick={() => setShowDropdown(!showDropdown)}
            className={`relative transition-all duration-300 ${
              showDropdown ? "ring-2 ring-primary/50 border-primary/50" : ""
            }`}
        >
          <Wallet className="mr-2 h-4 w-4" />
          Connect Wallet
            <ChevronDown
              className={`ml-2 h-4 w-4 transition-transform duration-300 ${
                showDropdown ? "rotate-180" : ""
              }`}
            />
        </Button>

        {showDropdown && (
            <>
            <div className="fixed inset-0 z-[90] bg-black/20 backdrop-blur-sm" />
            <div className="absolute top-full right-0 mt-3 z-[100]">
              <Card className="min-w-80 p-6 shadow-2xl border border-white/20 bg-black/90 backdrop-blur-xl">
                <div className="flex items-center justify-between mb-4">
                  <h3 className="text-lg font-bold text-white">
                            Connect Wallet
                          </h3>
                  <button
                    onClick={() => setShowDropdown(false)}
                    className="p-1 rounded-lg hover:bg-white/10 transition-colors"
                  >
                    <X className="h-4 w-4 text-white/60" />
                      </button>
        </div>

                <div className="space-y-2">
                  {wallets.map((wallet) => {
                    const displayInfo = getWalletDisplayInfo(wallet.name);
                    return (
                <button
                        key={wallet.name}
                        onClick={() => handleConnect(wallet.name)}
                        className="w-full p-3 rounded-lg bg-white/5 hover:bg-white/10 border border-white/10 hover:border-primary/30 transition-all duration-200 text-left flex items-center"
                      >
                        <span className="text-xl mr-3">{displayInfo.icon}</span>
                        <div>
                          <div className="font-medium text-white">
                            {wallet.name}
              </div>
                          <div className="text-sm text-white/60">
                            {displayInfo.description}
                      </div>
                    </div>
                  </button>
                    );
                  })}
                </div>
              </Card>
            </div>
          </>
        )}
      </div>
    );
  }

  return (
    <div className="relative" ref={dropdownRef}>
      <Button 
        variant="outline" 
        onClick={() => setShowDropdown(!showDropdown)}
          className={`relative transition-all duration-300 ${
          showDropdown ? "ring-2 ring-primary/50 border-primary/50" : ""
          }`}
      >
        <Wallet className="mr-2 h-4 w-4" />
        {formatAddress(currentAccount.address)}
          <ChevronDown
            className={`ml-2 h-4 w-4 transition-transform duration-300 ${
              showDropdown ? "rotate-180" : ""
            }`}
          />
      </Button>

      {showDropdown && (
          <>
          <div className="fixed inset-0 z-[90] bg-black/20 backdrop-blur-sm" />
          <div className="absolute top-full right-0 mt-3 z-[100]">
            <Card className="min-w-80 p-6 shadow-2xl border border-white/20 bg-black/90 backdrop-blur-xl">
              <div className="space-y-4">
                      <div className="flex items-center justify-between">
                  <h3 className="text-lg font-bold text-white">Account</h3>
                    <button
                    onClick={() => setShowDropdown(false)}
                    className="p-1 rounded-lg hover:bg-white/10 transition-colors"
                  >
                    <X className="h-4 w-4 text-white/60" />
                    </button>
                  </div>

                <div className="p-3 rounded-lg bg-white/5 border border-white/10">
                  <div className="text-sm text-white/60 mb-1">Address</div>
                  <div className="font-mono text-white text-sm break-all">
                    {currentAccount.address}
                  </div>
                </div>

                <div className="flex gap-2">
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => copyToClipboard(currentAccount.address)}
                    className="flex-1"
                  >
                    <Copy className="mr-2 h-4 w-4" />
                    {copiedAddress ? "Copied!" : "Copy"}
                  </Button>
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => openExplorer(currentAccount.address)}
                    className="flex-1"
                  >
                    <ExternalLink className="mr-2 h-4 w-4" />
                    Explorer
                  </Button>
                </div>

                <Button
                  variant="outline"
                  onClick={handleDisconnect}
                  className="w-full text-red-400 hover:text-red-300 hover:border-red-400/50"
                >
                  <LogOut className="mr-2 h-4 w-4" />
                  Disconnect
                </Button>
              </div>
            </Card>
          </div>
        </>
      )}
    </div>
  );
};

export default ConnectWalletButton; 
