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
        tx.object('0x1c1ae9b80d32d3f50a06dca57d42594f00f0eef7b074ffd01ca030ee53c9648a'),
        tx.object('0xd9baddab6aec8e3da594b0f0dfe256cb1c7197f10913f3a188ff7c850543a46d'),
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
