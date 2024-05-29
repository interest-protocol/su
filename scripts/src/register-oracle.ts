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
        tx.object('0x07f74eda1d94a6303d3a676e1693b265f76c866097a20b1c039b9954557fca51'),
        tx.object('0xbfb5f3985cee3e03d7e4f855a368aa14899217e73e593dc1de02b9037df39172'),
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
