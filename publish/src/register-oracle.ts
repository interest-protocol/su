import { TransactionBlock } from '@mysten/sui.js/transactions';

import { client, COIN_X_ORACLE_PACKAGE_ID, getId, keypair, SWITCHBOARD_AGGREGATOR } from './utils';

(async () => {
  try {
    console.log('calling...');

    const tx = new TransactionBlock();

    tx.moveCall({
      target: `${COIN_X_ORACLE_PACKAGE_ID}::switchboard_oracle::add`,
      typeArguments: [`${getId('package')}::oracle::SuOracle`],
      arguments: [
        tx.object('0x4e1929072f793cd684dcd458b0f34af4f9954b3e1298c8f3e7550766c08141a8'),
        tx.object('0x86f9e1209be772c97c969640840b6af08ed1483a3198944bad7331ebde9f3f85'),
        tx.object(SWITCHBOARD_AGGREGATOR),
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
