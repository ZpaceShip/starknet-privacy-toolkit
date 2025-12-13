// src/badge-service.ts
// Donation Badge Service - handles proof generation + Starknet interaction

import { Account, Contract, RpcProvider, cairo, CallData } from 'starknet';
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

// Correct compiled ABI from donation_badge_verifier (Cairo 2.9.2 / Scarb 2.9.2)
// This ABI matches the exact types from the compiled contract class
const BADGE_ABI = [
  {
    type: 'impl',
    name: 'DonationBadgeImpl',
    interface_name: 'donation_badge_verifier::badge_contract::IDonationBadge',
  },
  {
    type: 'struct',
    name: 'core::array::Span::<core::felt252>',
    members: [
      {
        name: 'snapshot',
        type: '@core::array::Array::<core::felt252>',
      },
    ],
  },
  {
    type: 'struct',
    name: 'core::integer::u256',
    members: [
      {
        name: 'low',
        type: 'core::integer::u128',
      },
      {
        name: 'high',
        type: 'core::integer::u128',
      },
    ],
  },
  {
    type: 'enum',
    name: 'core::bool',
    variants: [
      {
        name: 'False',
        type: '()',
      },
      {
        name: 'True',
        type: '()',
      },
    ],
  },
  {
    type: 'interface',
    name: 'donation_badge_verifier::badge_contract::IDonationBadge',
    items: [
      {
        type: 'function',
        name: 'claim_badge',
        inputs: [
          {
            name: 'full_proof_with_hints',
            type: 'core::array::Span::<core::felt252>',
          },
          {
            name: 'threshold',
            type: 'core::integer::u256',
          },
          {
            name: 'donation_commitment',
            type: 'core::integer::u256',
          },
          {
            name: 'badge_tier',
            type: 'core::integer::u8',
          },
        ],
        outputs: [
          {
            type: 'core::bool',
          },
        ],
        state_mutability: 'external',
      },
      {
        type: 'function',
        name: 'has_badge',
        inputs: [
          {
            name: 'address',
            type: 'core::starknet::contract_address::ContractAddress',
          },
          {
            name: 'tier',
            type: 'core::integer::u8',
          },
        ],
        outputs: [
          {
            type: 'core::bool',
          },
        ],
        state_mutability: 'view',
      },
      {
        type: 'function',
        name: 'get_badge_tier',
        inputs: [
          {
            name: 'address',
            type: 'core::starknet::contract_address::ContractAddress',
          },
        ],
        outputs: [
          {
            type: 'core::integer::u8',
          },
        ],
        state_mutability: 'view',
      },
      {
        type: 'function',
        name: 'is_commitment_used',
        inputs: [
          {
            name: 'commitment',
            type: 'core::integer::u256',
          },
        ],
        outputs: [
          {
            type: 'core::bool',
          },
        ],
        state_mutability: 'view',
      },
      {
        type: 'function',
        name: 'get_badge_counts',
        inputs: [],
        outputs: [
          {
            type: '(core::integer::u64, core::integer::u64, core::integer::u64)',
          },
        ],
        state_mutability: 'view',
      },
      {
        type: 'function',
        name: 'get_verifier_address',
        inputs: [],
        outputs: [
          {
            type: 'core::starknet::contract_address::ContractAddress',
          },
        ],
        state_mutability: 'view',
      },
    ],
  },
  {
    type: 'constructor',
    name: 'constructor',
    inputs: [
      {
        name: 'verifier',
        type: 'core::starknet::contract_address::ContractAddress',
      },
    ],
  },
  {
    type: 'event',
    name: 'donation_badge_verifier::badge_contract::DonationBadge::BadgeClaimed',
    kind: 'struct',
    members: [
      {
        name: 'recipient',
        type: 'core::starknet::contract_address::ContractAddress',
        kind: 'key',
      },
      {
        name: 'tier',
        type: 'core::integer::u8',
        kind: 'data',
      },
      {
        name: 'commitment_hash',
        type: 'core::felt252',
        kind: 'data',
      },
    ],
  },
  {
    type: 'event',
    name: 'donation_badge_verifier::badge_contract::DonationBadge::Event',
    kind: 'enum',
    variants: [
      {
        name: 'BadgeClaimed',
        type: 'donation_badge_verifier::badge_contract::DonationBadge::BadgeClaimed',
        kind: 'nested',
      },
    ],
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

    // Get response as text first to handle large numbers
    const text = await response.text();
    
    // Parse with custom handling for large numbers in arrays
    const result = JSON.parse(text, (key, value) => {
      // Only convert numbers within the calldata array to strings
      if (key === 'calldata' && Array.isArray(value)) {
        return value.map(v => {
          if (typeof v === 'number' && !Number.isSafeInteger(v)) {
            // Large number that would become scientific notation
            return v.toString();
          }
          return v;
        });
      }
      return value;
    });

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

    console.log('[BadgeService] Proof from backend:', {
      calldataLength: result.calldata?.length,
      calldataType: typeof result.calldata,
      firstElement: result.calldata?.[0],
      firstElementType: typeof result.calldata?.[0]
    });

    // Parse calldata if it's a JSON string
    let calldataArray: string[];
    if (typeof result.calldata === 'string') {
      // Backend returned JSON string
      // Replace all numeric values with quoted strings to prevent scientific notation
      const quotedJson = result.calldata.replace(
        /:\s*(-?\d+\.?\d*(?:e[+-]?\d+)?)/gi,
        ': "$1"'
      ).replace(
        /\[(-?\d+\.?\d*(?:e[+-]?\d+)?)/gi,
        '["$1"'
      ).replace(
        /,\s*(-?\d+\.?\d*(?:e[+-]?\d+)?)/gi,
        ', "$1"'
      );
      
      calldataArray = JSON.parse(quotedJson);
      
      // Remove any remaining scientific notation by ensuring strings
      calldataArray = calldataArray.map(v => {
        const str = String(v);
        // Check if it contains scientific notation
        if (str.includes('e+') || str.includes('e-')) {
          console.warn('[BadgeService] Found scientific notation:', str);
          // Try to parse and convert properly
          const num = parseFloat(str);
          return num.toFixed(0);
        }
        return str;
      });
    } else if (Array.isArray(result.calldata)) {
      // Already an array
      calldataArray = result.calldata.map(v => String(v));
    } else {
      throw new Error('Invalid calldata format from backend');
    }

    console.log('[BadgeService] Parsed calldata:', {
      length: calldataArray.length,
      firstElement: calldataArray[0],
      lastElement: calldataArray[calldataArray.length - 1],
      hasScientificNotation: calldataArray.some(v => v.includes('e+') || v.includes('e-'))
    });

    return {
      fullProofWithHints: calldataArray,
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

    // In starknet.js v8.9.1+, we need to create a new contract instance with the account
    const contractWithAccount = new Contract({
      abi: BADGE_ABI,
      address: this.contract.address,
      providerOrAccount: account
    });

    // Ensure all proof elements are strings (should already be from generateProof)
    const proofsArray: string[] = Array.isArray(badgeProof.fullProofWithHints)
      ? badgeProof.fullProofWithHints.map(p => String(p))
      : [String(badgeProof.fullProofWithHints)];

    console.log('[BadgeService] Badge proof data:', {
      threshold: badgeProof.threshold,
      commitment: badgeProof.donationCommitment,
      badgeTier: badgeProof.badgeTier,
      proofsLength: proofsArray.length,
      firstProofElement: proofsArray[0],
      firstProofType: typeof proofsArray[0],
      hasScientificNotation: proofsArray.some(p => p.includes('e+') || p.includes('e-'))
    });

    // Use the contract method directly - this uses the ABI for proper serialization
    // This ensures Span<felt252> and u256 types are serialized correctly
    console.log('[BadgeService] Invoking claim_badge with:', {
      proofsLength: proofsArray.length,
      threshold: badgeProof.threshold,
      commitment: badgeProof.donationCommitment,
      tier: badgeProof.badgeTier
    });

    // Pre-chequeo: evitar revert por commitment ya usado
    try {
      const commitmentBigInt = BigInt(badgeProof.donationCommitment);
      const res = await contractWithAccount.call('is_commitment_used', [
        {
          low: commitmentBigInt & ((1n << 128n) - 1n),
          high: commitmentBigInt >> 128n,
        },
      ]);
      const used = Boolean(res);
      if (used) {
        throw new Error('Commitment already used. Regenera la prueba con un donor_secret nuevo.');
      }
    } catch (e) {
      if ((e as Error).message.includes('already used')) {
        throw e;
      }
      console.warn('[BadgeService] No se pudo verificar is_commitment_used antes del claim:', e);
    }

    // Use contract.invoke() which handles serialization using the ABI
    const tx = await contractWithAccount.invoke('claim_badge', [
      proofsArray,
      cairo.uint256(badgeProof.threshold),
      cairo.uint256(badgeProof.donationCommitment),
      badgeProof.badgeTier
    ]);

    console.log('[BadgeService] Transaction submitted:', {
      transaction_hash: tx.transaction_hash
    });

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

