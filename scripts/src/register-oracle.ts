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
        tx.object('0x2ececf053400f800d68cc352617384615bc079057b810d75573ea5309156db2d'),
        tx.object('0x1a86869898590e9d133b56fbbe80f8705ea78ad8be65aef2ca9abea3d4c1bd90'),
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
