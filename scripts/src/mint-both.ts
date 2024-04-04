import { TransactionBlock } from '@mysten/sui.js/transactions';
import { SUI_CLOCK_OBJECT_ID } from '@mysten/sui.js/utils';

import { client, getId, keypair, requestPriceOracle } from './utils';

(async () => {
  try {
    console.log('calling...');

    const txb = new TransactionBlock();

    const [coin_i_sui_] = txb.moveCall({
      target: `${getId('package')}::i_sui::mint`,
      arguments: [txb.object('0xbeea2f45c6773657b0f0ead06575320f6950fc20b885b7d236de64ef429aa6c6'), txb.pure('1000000000000')],
    });

    const [tx, price] = requestPriceOracle(txb);

    const [coin_f, coin_x] = tx.moveCall({
      target: `${getId('package')}::vault::mint_both`,
      arguments: [
        tx.object('0x8d9ca1c1bb9ccc36f32431709f9150fe06946b5a51ccc896e3f9b4adc5390194'),
        tx.object('0xa78102f672af7b0f9e24f36b1fc3175b30e447b3c7b461a354c19833a5451b08'),
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
