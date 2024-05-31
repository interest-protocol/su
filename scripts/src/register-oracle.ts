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
        tx.object('0xac54a5196667dc8041d845f9fadb2bc999d2607a2acfe239a0c690d424972bdb'),
        tx.object('0xeb2ecadc73b39f44a7cb26c4505868967466759fb174c06c8a61757412546e68'),
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
