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
        tx.object('0xe9da66287ae46f6458af969b399d451adba5616e78bbb66977bdea921340fdea'),
        tx.object('0xa3f2347d0f375aa67d03c077833bf6aaba8a592886dad3903bd7863cb1e63f16'),
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
