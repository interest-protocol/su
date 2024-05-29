import { TransactionBlock } from '@mysten/sui.js/transactions';
import { SUI_CLOCK_OBJECT_ID } from '@mysten/sui.js/utils';

import { client, getId, keypair, requestPriceOracle } from './utils';

(async () => {
  try {
    console.log('calling...');

    const txb = new TransactionBlock();

    const [coin_i_sui_] = txb.moveCall({
      target: `${getId('package')}::i_sui::mint`,
      arguments: [txb.object('0xfda8eb4e7f4a8bc85e8486bda76532cbc28d3ce1731dedc888176d301ab0e9b2'), txb.pure('1000000000000')],
    });

    const [tx, price] = requestPriceOracle(txb);

    const [coin_d, coin_f, coin_x] = tx.moveCall({
      target: `${getId('package')}::vault::mint_both`,
      arguments: [
        tx.object('0xadfd43e2ed8c9b27d242076b2a00aa46163b8bcba702b21f0b9705ebb8698519'),
        tx.object('0x075034271340d249054bf950c852b03cf6f6f2347813e0332bf86163900a923f'),
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
