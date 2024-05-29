import { TransactionBlock } from '@mysten/sui.js/transactions';
import { SUI_CLOCK_OBJECT_ID } from '@mysten/sui.js/utils';

import { client, getId, keypair, requestPriceOracle } from './utils';

(async () => {
  try {
    console.log('calling...');

    const [tx, price] = requestPriceOracle(new TransactionBlock());

    tx.moveCall({
      target: `${getId('package')}::vault::share_genesis_state`,
      arguments: [
        tx.object('0xae1925e5d4cd10c2aaf6bac4977abd40b0a195d6d7233d4d0ccc28a9f3370e7c'),
        tx.object('0xd8198ea6315011a5917b1d443a37734e6ad1b429df66b1020d71a6c974422121'),
        tx.object('0x9ab81726755e963354d2ffc82fc6b0cdd034289883520837357ff82bafd0df1b'),
        tx.object(SUI_CLOCK_OBJECT_ID),
        price,
        tx.pure('100000000000000000'),
      ],
    });

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
