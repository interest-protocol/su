import { TransactionBlock } from '@mysten/sui.js/transactions';

import { client, getId, keypair } from './utils.js';

(async () => {
  try {
    console.log('calling...');

    const tx = new TransactionBlock();

    tx.setGasBudget(10000000);

    let [returned_object] = tx.moveCall({
      target: `${getId('package')}::module_name::function_name`,
      arguments: [getId('module_name::Type_name'), 'other_objet_id'],
    });

    tx.transferObjects([returned_object], keypair.getPublicKey().toSuiAddress());

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
