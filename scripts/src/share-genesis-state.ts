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
        tx.object('0x56765687fd4a71f8e58073dc30b52744e5310bf84559f67338a2ea19fa8ae371'),
        tx.object('0x3953ae956abc2005de492e18ba4959e9db67bd67e5c058b0a62712a749c975f0'),
        tx.object('0xe7b447bb77b6e8502b81d4281468a043ce545f1f17370064b14393d479cd5444'),
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
