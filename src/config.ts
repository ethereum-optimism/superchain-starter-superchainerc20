import { createConfig, http } from 'wagmi';
import { Network, supersimNetwork } from '@/networks';
import { Chain } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';

export const tokenAddress = '0x27538cbf66b94a54af2420192dd78d80621d6769' as const;

// Also assumed to be the owner of the token, owning the entire supply
export const defaultAccount = privateKeyToAccount(
  '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80'
);

export const network = supersimNetwork;

// When using using the interop-alpha chains, use the following config:
// export const network = interopAlphaNetwork;

const createConfigFromNetwork = (network: Network) => {
  return createConfig({
    chains: network.chains as [Chain, ...Chain[]],
    transports: Object.fromEntries(network.chains.map(chain => [chain.id, http()])),
  });
};

export const config = createConfigFromNetwork(network);
