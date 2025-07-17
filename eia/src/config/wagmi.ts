import { http, createConfig } from 'wagmi';
import { mainnet, polygon, optimism, arbitrum } from 'wagmi/chains';
import { injected, metaMask, safe, walletConnect } from 'wagmi/connectors';

const projectId = 'YOUR_WALLETCONNECT_PROJECT_ID'; // Replace with your WalletConnect project ID

export const config = createConfig({
  chains: [mainnet, polygon, optimism, arbitrum],
  connectors: [
    injected(),
    metaMask(),
    walletConnect({ projectId }),
    safe(),
  ],
  transports: {
    [mainnet.id]: http(),
    [polygon.id]: http(),
    [optimism.id]: http(),
    [arbitrum.id]: http(),
  },
}); 