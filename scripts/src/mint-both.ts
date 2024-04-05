import { TransactionBlock } from '@mysten/sui.js/transactions';
import { SUI_CLOCK_OBJECT_ID } from '@mysten/sui.js/utils';

import { client, getId, keypair, requestPriceOracle } from './utils';

(async () => {
  try {
    console.log('calling...');

    const txb = new TransactionBlock();

    const [coin_i_sui_] = txb.moveCall({
      target: `${getId('package')}::i_sui::mint`,
      arguments: [txb.object('0xf6c403b69a614ecd7a81ad73790cba950d8421da23ea1d04092ce383dd49210c'), txb.pure('1000000000000')],
    });

    const [tx, price] = requestPriceOracle(txb);

    const [coin_f, coin_x] = tx.moveCall({
      target: `${getId('package')}::vault::mint_both`,
      arguments: [
        tx.object('0xd531d4c34c4808c39252ca28fe7b74bda215ce65231bbcb8a6312f337ec8e3ba'),
        tx.object('0x1380a6aa6f3ab4953c54839105840270d988baaba4ee2cdd6417381856015eda'),
        tx.object(SUI_CLOCK_OBJECT_ID),
        coin_i_sui_,
        price,
        tx.pure('0'),
        tx.pure('0'),
      ],
    });

    tx.transferObjects([coin_f, coin_x], tx.pure('0x73c9dcc625ec28521d66ad5cf5652204175e9130782053fffd1d9431f0bbc01d'));

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
