import { TransactionBlock } from '@mysten/sui.js/transactions';
import { SUI_CLOCK_OBJECT_ID } from '@mysten/sui.js/utils';

import { client, getId, keypair, requestPriceOracle } from './utils';

(async () => {
  try {
    console.log('calling...');

    const txb = new TransactionBlock();

    const [coin_i_sui_] = txb.moveCall({
      target: `${getId('package')}::i_sui::mint`,
      arguments: [txb.object('0x904845ee460e4e1fd5666eca33167f13cf24c92fc0bf2bbc22026efc6ddfd28d'), txb.pure('1000000000000')],
    });

    const [tx, price] = requestPriceOracle(txb);

    const [coin_d, coin_f, coin_x] = tx.moveCall({
      target: `${getId('package')}::vault::mint_all`,
      arguments: [
        tx.object('0xb8db2f10d83427da080e9525a13af9bcd77f2a942e8a7cc5ca5d7604688872f2'),
        tx.object('0xe82c24162e348b48ca587e3ee572821164718416cbbe21400e248861b29ceadb'),
        tx.object(SUI_CLOCK_OBJECT_ID),
        coin_i_sui_,
        price,
        tx.pure('0'),
        tx.pure('0'),
        tx.pure('0'),
      ],
    });

    tx.transferObjects([coin_d, coin_f, coin_x], tx.pure('0x73c9dcc625ec28521d66ad5cf5652204175e9130782053fffd1d9431f0bbc01d'));

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
