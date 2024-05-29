import { TransactionBlock } from '@mysten/sui.js/transactions';
import { SUI_CLOCK_OBJECT_ID } from '@mysten/sui.js/utils';

import { client, getId, keypair, requestPriceOracle } from './utils';

(async () => {
  try {
    console.log('calling...');

    const txb = new TransactionBlock();

    const [coin_i_sui_] = txb.moveCall({
      target: `${getId('package')}::i_sui::mint`,
      arguments: [txb.object('0xe362e8af74717dd9c617a315205f6e05c7481ce676a907e1b2951f00fdcbb098'), txb.pure('1000000000000')],
    });

    const [tx, price] = requestPriceOracle(txb);

    const [coin_d, coin_f, coin_x] = tx.moveCall({
      target: `${getId('package')}::vault::mint_all`,
      arguments: [
        tx.object('0x287c1236628767a73c69bb705ed83845202d2da6bb9713f1ada1a359bd70e899'),
        tx.object('0x3cbb1e87c276c08acbf646c2cb0764977e4eb8d3f33c89a3e6350d4d321f53d3'),
        tx.object(SUI_CLOCK_OBJECT_ID),
        coin_i_sui_,
        price,
        tx.pure('0'),
        tx.pure('0'),
        tx.pure('0'),
      ],
    });

    tx.transferObjects([coin_d, coin_f, coin_x], tx.pure('0x73c9dcc625ec28521d66ad5cf5652204175e9130782053fffd1d9431f0bbc01d'));

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
