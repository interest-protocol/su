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
        tx.object('0x41fea40036ac51bdd295fbab85ac71865259dfccaf81476a8efee10b81b1221e'),
        tx.object('0xd585ab6b816ae31d73e64a54f1a4c2f0f2ece2b83c79650d6686f56772bd354c'),
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
