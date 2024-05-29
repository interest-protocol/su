import { getFullnodeUrl, SuiClient } from '@mysten/sui.js/client';
import { Ed25519Keypair } from '@mysten/sui.js/keypairs/ed25519';
import { TransactionBlock } from '@mysten/sui.js/transactions';
import { SUI_CLOCK_OBJECT_ID } from '@mysten/sui.js/utils';
import dotenv from 'dotenv';
import * as fs from 'fs';

dotenv.config();

export interface IObjectInfo {
  type: string | undefined;
  id: string | undefined;
}

export const keypair = Ed25519Keypair.fromSecretKey(Uint8Array.from(Buffer.from(process.env.KEY!, 'base64')).slice(1));

export const client = new SuiClient({ url: getFullnodeUrl('testnet') });

export const SUITEARS_PACKAGE_ID = '0xbd097359082272fdef8e9ce53815264d0142d6209f3f0cb48ee31c10aaf846d5';

export const SWITCHBOARD_AGGREGATOR = '0x84d2b7e435d6e6a5b137bf6f78f34b2c5515ae61cd8591d5ff6cd121a21aa6b7';

export const COIN_X_ORACLE_PACKAGE_ID = '0x667df8861d3b005d9c16b30d451c539a53cef961c75951686c095c011e4a7050';

export const VAULT = '0xadfd43e2ed8c9b27d242076b2a00aa46163b8bcba702b21f0b9705ebb8698519';

export const TREASURY = '0x075034271340d249054bf950c852b03cf6f6f2347813e0332bf86163900a923f';

const ORACLE = '0xb581ff1a97da5bc298e700bb18843798dbce4b97e06ffec2e60d81c13301a3cf';

export const getId = (type: string): string | undefined => {
  try {
    const rawData = fs.readFileSync('./su.json', 'utf8');
    const parsedData: IObjectInfo[] = JSON.parse(rawData);
    const typeToId = new Map(parsedData.map((item) => [item.type, item.id]));
    return typeToId.get(type);
  } catch (error) {
    console.error('Error reading the Su file:', error);
  }
};

export const requestPriceOracle = (txb: TransactionBlock): [TransactionBlock, any] => {
  const request = txb.moveCall({
    typeArguments: [`${getId('package')}::oracle::SuOracle`],
    target: `${SUITEARS_PACKAGE_ID}::oracle::request`,
    arguments: [txb.object(ORACLE)],
  });

  txb.moveCall({
    typeArguments: [`${getId('package')}::oracle::SuOracle`],
    target: `${COIN_X_ORACLE_PACKAGE_ID}::switchboard_oracle::report`,
    arguments: [txb.object(ORACLE), request, txb.object(SWITCHBOARD_AGGREGATOR)],
  });

  const [price] = txb.moveCall({
    typeArguments: [`${getId('package')}::oracle::SuOracle`],
    target: `${SUITEARS_PACKAGE_ID}::oracle::destroy_request`,
    arguments: [txb.object(ORACLE), request, txb.object(SUI_CLOCK_OBJECT_ID)],
  });

  return [txb, price];
};
// 3,600,000
