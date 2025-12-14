# Proof Generation Pipeline

## Overview

The ZK badge proof generation is fully automated inside Docker and can be run reproducibly via the docker-helper script.

## Complete Pipeline (End-to-End)

```bash
# From repository root
./docker-helper.sh exec bash -lc "cd /app/zk-badges && ./generate-proof.sh <amount_cents> <secret> <tier>"
```

**Parameters:**
- `<amount_cents>`: Donation amount in cents (e.g., 100000 = $1000)
- `<secret>`: Donor secret (any string, kept private)
- `<tier>`: Badge tier: 1=Bronze (≥$10), 2=Silver (≥$100), 3=Gold (≥$1000)

**Example: Gold Badge Proof**
```bash
./docker-helper.sh exec bash -lc "cd /app/zk-badges && ./generate-proof.sh 100000 mydonationsecret 3"
```

## What Happens Inside

1. **Poseidon Commitment** (Bun) – Hashes `(donor_secret, amount)` using circomlibjs
2. **Noir Compilation** – Compiles the circuit with threshold validation
3. **Witness Generation** – Noir executes the circuit with your inputs
4. **Proof Generation** (Barretenberg) – Ultra Keccak Honk proof generation
5. **Verification Key** (Barretenberg) – Generates VK for on-chain verification
6. **Calldata Export** (Garaga) – Converts proof to Starknet calldata format

## Output

- **Proof binary**: `/app/zk-badges/donation_badge/target/proof.bin`
- **Verification key**: `/app/zk-badges/donation_badge/target/vk`
- **Calldata JSON**: `/app/zk-badges/calldata.json`
- **Public inputs**:
  - `threshold`: Minimum donation for the tier
  - `commitment`: Poseidon hash of (secret, amount)
  - `tier`: Badge tier (1, 2, or 3)

## Docker Reproducibility

All ZK tools are pre-installed in the Docker image:
- **Noir** 1.0.0-beta.1 (nargo)
- **Barretenberg** 0.67.0 (bb)
- **Garaga** 0.15.5
- **Scarb** 2.9.2 (Cairo compiler)
- **Bun** (runtime for Poseidon commitment)

Build the image once:
```bash
./docker-helper.sh rebuild
```

Then run proofs any time without additional setup:
```bash
./docker-helper.sh start
./docker-helper.sh exec bash -lc "cd /app/zk-badges && ./generate-proof.sh 100000 secret 3"
```

## Troubleshooting

### Assertion Failed: Donation below threshold
The amount is below the minimum for the selected tier.
- Bronze (1): ≥ 1000 cents ($10)
- Silver (2): ≥ 10000 cents ($100)
- Gold (3): ≥ 100000 cents ($1000)

### Node/Bun not found
Already fixed in Dockerfile (v2.2+). Rebuild with `./docker-helper.sh rebuild`.

### Garaga calldata error
Known issue with VK format parsing (Garaga 0.15.5). The proof binary is valid; pass the commitment and tier directly to the on-chain `claim_badge` function.

## Integration with Badge Claiming

Use the proof + public inputs in the frontend badge claim:

```javascript
await claimBadge({
  proof: calldata.proof_array,
  threshold: 100000,
  donation_commitment: commitment_u256,
  badge_tier: 3
});
```

See `src/badge-service.ts` for integration.
