#!/usr/bin/env node
const { RpcProvider } = require('starknet');

const provider = new RpcProvider({
  nodeUrl: 'https://starknet-sepolia.g.alchemy.com/starknet/version/rpc/v0_9/cf52O0RwFy1mEB0uoYsel'
});

const badgeClassHash = '0x04bedab69579e1f888f408aa5a96462228ba94b91c736367664c0cb41460c36c';

async function analyzeContract() {
  console.log('📥 Descargando contrato desplegado...\n');
  
  const contractClass = await provider.getClassByHash(badgeClassHash);
  
  // Convertir a JSON string para buscar
  const jsonStr = JSON.stringify(contractClass);
  
  if (jsonStr.includes('Commitment conversion failed')) {
    console.log('❌ CONFIRMADO: El contrato desplegado TIENE el bug');
    console.log('   Contiene: "Commitment conversion failed"');
    console.log('');
    console.log('   Versión desplegada (código antiguo):');
    console.log('   let commitment_low: felt252 = (donation_commitment & COMMITMENT_MASK)');
    console.log('       .try_into()');
    console.log('       .expect("Commitment conversion failed");');
    console.log('');
    console.log('   ⚠️  ESTE ES EL PROBLEMA RAÍZ');
  } else {
    console.log('✅ El contrato desplegado NO contiene ese mensaje');
    console.log('   El problema debe estar en otro lugar');
  }
  
  // Buscar otros mensajes
  const errorMessages = [
    'Commitment already used',
    'Invalid badge tier',
    'Proof verification failed',
    'Threshold mismatch',
    'Commitment mismatch',
    'Tier mismatch',
    'Tier conversion failed'
  ];
  
  console.log('\n📋 Otros mensajes de error en el contrato:');
  errorMessages.forEach(msg => {
    if (jsonStr.includes(msg)) {
      console.log('   ✓', msg);
    }
  });
}

analyzeContract().catch(console.error);
