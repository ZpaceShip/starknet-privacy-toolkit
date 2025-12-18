declare module 'circomlibjs' {
  export interface PoseidonHasher {
    (inputs: bigint[]): bigint;
    F: {
      toString(value: bigint): string;
    };
  }

  export function buildPoseidon(): Promise<PoseidonHasher>;
}
