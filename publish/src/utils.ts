import { getFullnodeUrl, SuiClient } from '@mysten/sui.js/client';
import { Ed25519Keypair } from '@mysten/sui.js/keypairs/ed25519';
import { TransactionBlock, TransactionResult } from '@mysten/sui.js/transactions';
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

export const SUITEARS_PACKAGE_ID = '0x901b511b878f90f1b833df46648224b913df60f8b3165086caba6f59e75d6e98';

export const SWITCHBOARD_AGGREGATOR = '0x84d2b7e435d6e6a5b137bf6f78f34b2c5515ae61cd8591d5ff6cd121a21aa6b7';

export const COIN_X_ORACLE_PACKAGE_ID = '0xf60ef86bf632916f96c0c46e386dd30e78c971463e880d462893045906af2a69';

export const VAULT = '0xdea4e8ea65a949b800ee1b07e8714c7db43c84c3498f2f4bf046fd9ee38dfec4';

export const TREASURY = '0x3593eec51a3b86c2d794e00bdcaaa9255e44bddbdc7cf3f6e5b62231b7dc187c';

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
    arguments: [txb.object('0x4e1929072f793cd684dcd458b0f34af4f9954b3e1298c8f3e7550766c08141a8')],
  });

  txb.moveCall({
    typeArguments: [`${getId('package')}::oracle::SuOracle`],
    target: `${COIN_X_ORACLE_PACKAGE_ID}::switchboard_oracle::report`,
    arguments: [txb.object('0x4e1929072f793cd684dcd458b0f34af4f9954b3e1298c8f3e7550766c08141a8'), request, txb.object(SWITCHBOARD_AGGREGATOR)],
  });

  const [price] = txb.moveCall({
    typeArguments: [`${getId('package')}::oracle::SuOracle`],
    target: `${SUITEARS_PACKAGE_ID}::oracle::destroy_request`,
    arguments: [txb.object('0x4e1929072f793cd684dcd458b0f34af4f9954b3e1298c8f3e7550766c08141a8'), request, txb.object(SUI_CLOCK_OBJECT_ID)],
  });

  return [txb, price];
};
// 3,600,000
