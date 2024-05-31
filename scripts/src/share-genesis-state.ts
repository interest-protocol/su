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
        tx.object('0x297999a5b7070f3241be4ef14075baad45351f177aaefaa686d5a26e6171bac0'),
        tx.object('0x9ae17118997a0eacf24db09587dda299823d70942f1533dda0a07c08c4b81d20'),
        tx.object('0x26d68894d253d953f7bf713f6f7b0a354a5d4a578015165001ee5848c440203a'),
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
