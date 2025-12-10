// src/badge-service.ts
// Donation Badge Service - handles proof generation + Starknet interaction

import { Account, Contract, RpcProvider } from 'starknet';
import { getContractAddress } from './deployments';

export enum BadgeTier {
  NONE = 0,
  BRONZE = 1,
  SILVER = 2,
  GOLD = 3,
}

// Lazy initialization to avoid module loading issues
function getBadgeContractAddress(network: 'mainnet' | 'sepolia'): string {
  try {
    return getContractAddress(network, 'DonationBadge');
  } catch (error) {
    console.warn(`[BadgeService] Could not get contract address for ${network}:`, error);
    return '0x0';
  }
}

// Simplified ABI - only define the functions we actually use
const BADGE_ABI = [
  {
    type: 'function',
    name: 'get_badge_tier',
    inputs: [
      {
        name: 'address',
        type: 'felt',
      },
    ],
    outputs: [
      {
        type: 'u8',
      },
    ],
    state_mutability: 'view',
  },
  {
    type: 'function',
    name: 'claim_badge',
    inputs: [
      {
        name: 'full_proof_with_hints',
        type: 'felt*',
      },
      {
        name: 'threshold',
        type: 'u256',
      },
      {
        name: 'donation_commitment',
        type: 'u256',
      },
      {
        name: 'badge_tier',
        type: 'u8',
      },
    ],
    outputs: [
      {
        type: 'bool',
      },
    ],
    state_mutability: 'external',
  },
];

export interface DonationProofInput {
  donationAmountCents: number;
  donorSecret: string;
  targetTier: BadgeTier;
}

export interface BadgeProof {
  fullProofWithHints: string[];
  threshold: string;
  donationCommitment: string;
  badgeTier: number;
}

export interface ProofGenerationStatus {
  stage: 'idle' | 'generating_proof' | 'complete' | 'error';
  message: string;
  progress?: number;
}

export class BadgeService {
  private provider: RpcProvider;
  private contract: Contract | null = null;
  private network: 'mainnet' | 'sepolia';
  private proofBackendUrl: string;

  constructor(
    provider: RpcProvider,
    network: 'mainnet' | 'sepolia' = 'sepolia',
    proofBackendUrl?: string,
  ) {
    this.provider = provider;
    // Force Sepolia for badges until mainnet deployment is ready
    this.network = 'sepolia';
    
    // Use relative URL for API calls - Vite proxy will handle routing
    // This works in all environments (local, Docker, Codespaces)
    this.proofBackendUrl = proofBackendUrl || '/api/generate-proof';

    const contractAddress = getBadgeContractAddress(this.network);
    console.log('[BadgeService] Initializing with contract address:', contractAddress);
    console.log('[BadgeService] ABI type:', typeof BADGE_ABI, 'ABI length:', BADGE_ABI?.length);
    
    if (contractAddress && contractAddress !== '0x0') {
      try {
        // Create contract instance using starknet.js v8.9.1 format
        // Constructor: new Contract({ abi, address, providerOrAccount })
        this.contract = new Contract({
          abi: BADGE_ABI,
          address: contractAddress,
          providerOrAccount: provider
        });
        console.log('[BadgeService] Contract instance created successfully');
      } catch (error) {
        console.error('[BadgeService] Failed to initialize contract:', error);
        console.error('[BadgeService] Will continue without contract instance');
        this.contract = null;
      }
    } else {
      console.warn('[BadgeService] Contract address is missing or zero');
    }
  }

  isContractDeployed(): boolean {
    const address = getBadgeContractAddress(this.network);
    return Boolean(address && address !== '0x0');
  }

  getTierThreshold(tier: BadgeTier): number {
    switch (tier) {
      case BadgeTier.BRONZE:
        return 1000;
      case BadgeTier.SILVER:
        return 10000;
      case BadgeTier.GOLD:
        return 100000;
      default:
        return 0;
    }
  }

  getTierName(tier: BadgeTier): string {
    switch (tier) {
      case BadgeTier.BRONZE:
        return '🥉 Bronze Donor ($10+)';
      case BadgeTier.SILVER:
        return '🥈 Silver Donor ($100+)';
      case BadgeTier.GOLD:
        return '🥇 Gold Donor ($1000+)';
      default:
        return 'No Badge';
    }
  }

  getEligibleTier(amountCents: number): BadgeTier {
    if (amountCents >= 100000) return BadgeTier.GOLD;
    if (amountCents >= 10000) return BadgeTier.SILVER;
    if (amountCents >= 1000) return BadgeTier.BRONZE;
    return BadgeTier.NONE;
  }

  async generateProof(
    input: DonationProofInput,
    onStatusUpdate?: (status: ProofGenerationStatus) => void,
  ): Promise<BadgeProof> {
    const threshold = this.getTierThreshold(input.targetTier);

    if (input.donationAmountCents < threshold) {
      throw new Error(
        `Donation amount $${(input.donationAmountCents / 100).toFixed(2)} is below ` +
          `threshold $${(threshold / 100).toFixed(2)} for ${this.getTierName(input.targetTier)}`,
      );
    }

    onStatusUpdate?.({
      stage: 'generating_proof',
      message: 'Generating ZK proof (up to 60 seconds)...',
      progress: 30,
    });

    // Convert donor secret string to a numeric value
    // Use a simple hash: sum of char codes
    let secretNumeric = 0;
    for (let i = 0; i < input.donorSecret.length; i++) {
      secretNumeric = (secretNumeric * 31 + input.donorSecret.charCodeAt(i)) % Number.MAX_SAFE_INTEGER;
    }

    const response = await fetch(this.proofBackendUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        donationamount: input.donationAmountCents,
        donorsecret: secretNumeric.toString(),
        threshold,
        badgetier: input.targetTier,
      }),
    });

    if (!response.ok) {
      const error = await response.text();
      onStatusUpdate?.({ stage: 'error', message: error });
      throw new Error(`Proof generation failed: ${error}`);
    }

    const result = await response.json();

    onStatusUpdate?.({
      stage: 'complete',
      message: 'Proof generated successfully!',
      progress: 100,
    });

    const donationCommitment =
      result.donation_commitment ?? result.commitment ?? result.commitment_hex;

    if (!donationCommitment) {
      throw new Error('Proof generation response missing commitment');
    }

    return {
      fullProofWithHints: result.calldata,
      threshold: threshold.toString(),
      donationCommitment: donationCommitment.toString(),
      badgeTier: input.targetTier,
    };
  }

  async claimBadge(account: Account, badgeProof: BadgeProof): Promise<string> {
    if (!this.contract || !this.isContractDeployed()) {
      throw new Error(
        'Badge contract not deployed. Please deploy and update BADGE_CONTRACT_ADDRESS.',
      );
    }

    this.contract.connect(account);

    const thresholdBigInt = BigInt(badgeProof.threshold);
    const commitmentBigInt = BigInt(badgeProof.donationCommitment);

    const tx = await this.contract.invoke('claim_badge', [
      badgeProof.fullProofWithHints,
      {
        low: thresholdBigInt & ((1n << 128n) - 1n),
        high: thresholdBigInt >> 128n,
      },
      {
        low: commitmentBigInt & ((1n << 128n) - 1n),
        high: commitmentBigInt >> 128n,
      },
      badgeProof.badgeTier,
    ]);

    await this.provider.waitForTransaction(tx.transaction_hash);
    return tx.transaction_hash;
  }

  async getUserBadgeTier(address: string): Promise<BadgeTier> {
    if (!this.contract || !this.isContractDeployed()) {
      return BadgeTier.NONE;
    }

    try {
      const tier = await this.contract.call('get_badge_tier', [address]);
      return Number(tier) as BadgeTier;
    } catch {
      return BadgeTier.NONE;
    }
  }

  async hasBadge(address: string, tier: BadgeTier): Promise<boolean> {
    if (!this.contract || !this.isContractDeployed()) {
      return false;
    }
    try {
      const result = await this.contract.call('has_badge', [address, tier]);
      return Boolean(result);
    } catch {
      return false;
    }
  }

  async isCommitmentUsed(commitment: string): Promise<boolean> {
    if (!this.contract || !this.isContractDeployed()) {
      return false;
    }
    try {
      const commitmentBigInt = BigInt(commitment);
      const result = await this.contract.call('is_commitment_used', [
        {
          low: commitmentBigInt & ((1n << 128n) - 1n),
          high: commitmentBigInt >> 128n,
        },
      ]);
      return Boolean(result);
    } catch {
      return false;
    }
  }

  async getBadgeCounts(): Promise<{ bronze: number; silver: number; gold: number }> {
    if (!this.contract || !this.isContractDeployed()) {
      return { bronze: 0, silver: 0, gold: 0 };
    }
    try {
      const result = (await this.contract.call('get_badge_counts', [])) as [
        bigint,
        bigint,
        bigint,
      ];
      return {
        bronze: Number(result[0]),
        silver: Number(result[1]),
        gold: Number(result[2]),
      };
    } catch {
      return { bronze: 0, silver: 0, gold: 0 };
    }
  }
}

