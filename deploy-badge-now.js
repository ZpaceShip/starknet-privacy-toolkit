#!/usr/bin/env node
/**
 * Deploy new Badge Contract using starknet.js
 */

const fs = require('fs');
const { Account, RpcProvider, Contract, json, hash } = require('starknet');

const SEPOLIA_RPC = 'https://starknet-sepolia.g.alchemy.com/starknet/version/rpc/v0_7/cf52O0RwFy1mEB0uoYsel';
const VERIFIER_ADDRESS = '0x022b20fef3764d09293c5b377bc399ae7490e60665797ec6654d478d74212669';
const DEPLOYER_PRIVATE_KEY = process.env.DEPLOYER_PRIVATE_KEY;

async function deploy() {
  console.log('======================================');
  console.log('🚀 Deploying NEW Badge Contract');
  console.log('======================================\n');

  if (!DEPLOYER_PRIVATE_KEY) {
    console.error('❌ DEPLOYER_PRIVATE_KEY not set');
    process.exit(1);
  }

  // Read compiled contract
  const contractPath = '/tmp/badge_build/target/dev/donation_badge_verifier_DonationBadge.contract_class.json';
  const compiledContractCasm = '/tmp/badge_build/target/dev/donation_badge_verifier_DonationBadge.compiled_contract_class.json';
  
  const sierraContract = JSON.parse(fs.readFileSync(contractPath, 'utf8'));
  const casmContract = JSON.parse(fs.readFileSync(compiledContractCasm, 'utf8'));

  console.log('📦 Contract loaded from:', contractPath);

  // Setup provider and account
  const provider = new RpcProvider({ nodeUrl: SEPOLIA_RPC });
  
  // Derive address from private key
  const starkKeyPub = hash.computeHashOnElements([DEPLOYER_PRIVATE_KEY]);
  console.log('🔑 Using deployer account...\n');

  // We need the account address - let's try to get it
  let accountAddress;
  try {
    // Try common derivation methods
    const account = new Account(provider, '0x0', DEPLOYER_PRIVATE_KEY);
    // This might fail but it's okay
  } catch (e) {
    console.log('Note: Account address derivation skipped, will use during declare');
  }

  // For Argent/Braavos, we need to query the blockchain to find the account address
  console.log('📤 Step 1: Declaring contract class...');
  
  // Calculate class hash
  const classHash = hash.computeSierraContractClassHash(sierraContract);
  console.log('   Class hash:', classHash);

  try {
    // Check if already declared
    await provider.getClassByHash(classHash);
    console.log('✅ Class already declared\n');
  } catch (e) {
    console.log('   Class not yet declared, need to declare it');
    console.log('\n⚠️  Cannot auto-declare without account address.');
    console.log('   Please use this class hash with sncast or starkli:\n');
    console.log('   sncast declare --url', SEPOLIA_RPC);
    console.log('   --contract-name DonationBadge');
    console.log('   --private-key', DEPLOYER_PRIVATE_KEY.substring(0, 10) + '...\n');
    console.log('   Or save these files and declare manually:');
    console.log('   - Sierra:', contractPath);
    console.log('   - CASM:', compiledContractCasm);
    process.exit(1);
  }

  console.log('🚀 Step 2: Deploying contract...');
  console.log('   Verifier:', VERIFIER_ADDRESS);
  console.log('   Class hash:', classHash);

  // For deployment we also need the account
  console.log('\n⚠️  Need account address to deploy.');
  console.log('   Get your account address from your wallet and run:');
  console.log('\n   export DEPLOYER_ADDRESS=0x...');
  console.log('   export DEPLOYER_PRIVATE_KEY=' + DEPLOYER_PRIVATE_KEY.substring(0, 10) + '...');
  console.log('   node deploy-badge-now.js\n');
}

deploy().catch(console.error);
