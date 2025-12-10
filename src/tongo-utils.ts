/**
 * Utility functions for Tongo SDK integration.
 * These functions are extracted from @fatsolutions/tongo-sdk/dist/types.js
 * to avoid import issues with Vite's dependency pre-bundling.
 */

import { base58 } from '@scure/base';
import { bytesToHex } from '@noble/hashes/utils';
import { ProjectivePoint } from '@fatsolutions/tongo-sdk';

/**
 * Converts a base58 encoded public key string to affine point representation.
 * This function decodes the base58 string and creates a ProjectivePoint from the hex bytes.
 * 
 * @param b58string - The base58 encoded public key string
 * @returns ProjectivePoint representing the public key in affine coordinates
 * 
 * @example
 * const publicKey = 'E5vFp9...'; // base58 encoded key
 * const point = pubKeyBase58ToAffine(publicKey);
 */
export function pubKeyBase58ToAffine(b58string: string): typeof ProjectivePoint.prototype {
    const bytes = base58.decode(b58string);
    return ProjectivePoint.fromHex(bytesToHex(bytes));
}
