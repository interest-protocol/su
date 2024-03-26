import { TransactionBlock } from '@mysten/sui.js/transactions';
import { SUI_CLOCK_OBJECT_ID } from '@mysten/sui.js/utils';
import { client, COIN_X_ORACLE_PACKAGE_ID, getId, keypair, SWITCHBOARD_AGGREGATOR, requestPriceOracle } from './utils';

(async () => {
  try {
    console.log('calling...');

    const txb = new TransactionBlock();

    const [coin_i_sui_] = txb.moveCall({
      target: `0x93138c3abb7263fe606d685cac44b68d1dae5dfa1d89f3366d5ef26e9d6d9549::i_sui::mint`,
      arguments: [txb.object('0x22ca0850ebfefb2067b8658850af70a4943d24867f330941939ca9e6c3e5f4bd'), txb.pure('1000000000000')],
    });

    const [tx, price] = requestPriceOracle(txb);

    const [coin_f, coin_x] = tx.moveCall({
      target: `${getId('package')}::vault::mint_both`,
      arguments: [
        tx.object('0xdea4e8ea65a949b800ee1b07e8714c7db43c84c3498f2f4bf046fd9ee38dfec4'),
        tx.object('0x3593eec51a3b86c2d794e00bdcaaa9255e44bddbdc7cf3f6e5b62231b7dc187c'),
        tx.object(SUI_CLOCK_OBJECT_ID),
        coin_i_sui_,
        price,
        tx.pure('0'),
        tx.pure('0'),
      ],
    });

    tx.transferObjects([coin_f, coin_x], tx.pure('0x73c9dcc625ec28521d66ad5cf5652204175e9130782053fffd1d9431f0bbc01d'));

    const result = await client.signAndExecuteTransactionBlock({
      signer: keypair,
      transactionBlock: tx,
      options: {
        showObjectChanges: true,
        showEffects: true,
      },
      requestType: 'WaitForLocalExecution',
    });

    console.log('result: ', JSON.stringify(result.objectChanges, null, 2));
    console.log('status: ', JSON.stringify(result.effects?.status, null, 2));
  } catch (e) {
    console.log(e);
  }
})();
