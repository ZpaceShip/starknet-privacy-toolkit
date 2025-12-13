import { RpcProvider, Account, Contract, json } from "starknet";
import fs from "fs";

// Configuración
const SEPOLIA_RPC = "https://starknet-sepolia.g.alchemy.com/starknet/version/rpc/v0_7/cf52O0RwFy1mEB0uoYsel";
const ACCOUNT_ADDRESS = "0x05dB7a0D559d01406df3A80a78d3C1d38119aAd459880740f68d09aa67c1eD60";
const PRIVATE_KEY = "0x016b3c3cc01c4663b094207a16164baa528146181418edad7c77385970e7587b";

async function declareBadgeContract() {
  console.log("🚀 Iniciando declare del Badge Contract...\n");

  // 1. Conectar al RPC
  const provider = new RpcProvider({ nodeUrl: SEPOLIA_RPC });
  
  // 2. Crear cuenta (verificando que los valores no sean undefined)
  console.log("📝 Configurando cuenta:", ACCOUNT_ADDRESS);
  if (!ACCOUNT_ADDRESS || !PRIVATE_KEY) {
    throw new Error("ACCOUNT_ADDRESS o PRIVATE_KEY no están definidos");
  }
  const account = new Account(provider, ACCOUNT_ADDRESS, PRIVATE_KEY);
  
  // 3. Verificar balance
  try {
    const balance = await provider.getBalance(ACCOUNT_ADDRESS);
    console.log("💰 Balance STRK:", balance, "\n");
  } catch (e) {
    console.log("⚠️  No se pudo verificar balance\n");
  }

  // 4. Leer archivos compilados
  console.log("📂 Leyendo archivos compilados...");
  const sierraJson = json.parse(fs.readFileSync("./sierra.json").toString("utf-8"));
  const casmJson = json.parse(fs.readFileSync("./casm.json").toString("utf-8"));
  
  console.log("✅ Sierra cargado");
  console.log("✅ CASM cargado\n");

  // 5. Hacer declare
  console.log("📤 Enviando transacción de declare...");
  console.log("⏳ Esto puede tardar 1-2 minutos...\n");
  
  try {
    const declareResponse = await account.declareIfNot({
      contract: sierraJson,
      casm: casmJson,
    });

    console.log("✅ Declare exitoso!");
    console.log("\n📋 Detalles:");
    console.log("   - Class Hash:", declareResponse.class_hash);
    console.log("   - Transaction Hash:", declareResponse.transaction_hash);
    
    // Esperar confirmación
    console.log("\n⏳ Esperando confirmación en blockchain...");
    await provider.waitForTransaction(declareResponse.transaction_hash);
    
    console.log("\n✅ ¡Contrato declarado y confirmado en blockchain!");
    console.log("\n📝 Guarda este Class Hash para el deploy:");
    console.log("   ", declareResponse.class_hash);
    
    return declareResponse.class_hash;
    
  } catch (error) {
    console.error("\n❌ Error en declare:");
    console.error(error.message || error);
    
    if (error.message?.includes("insufficient")) {
      console.log("\n💡 Necesitas más STRK o ETH en tu wallet.");
      console.log("   Obtén del faucet: https://starknet-faucet.vercel.app/");
    }
    
    throw error;
  }
}

// Ejecutar
declareBadgeContract()
  .then((classHash) => {
    console.log("\n🎉 Todo listo! Class Hash:", classHash);
    console.log("\n🚀 Siguiente paso: Deploy con constructor parameter:");
    console.log("   0x022b20fef3764d09293c5b377bc399ae7490e60665797ec6654d478d74212669");
    process.exit(0);
  })
  .catch((error) => {
    console.error("\n💥 Error fatal:", error);
    process.exit(1);
  });
