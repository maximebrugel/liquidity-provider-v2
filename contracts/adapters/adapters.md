# Adapters

It can happen that projects fork UniswapV2 but they change the nomenclature.

For example, [HyperSwap](https://swap.hyperjump.fi) on Fantom Opera :

- swapExact**ETH**ForTokensSupportingFeeOnTransferTokens is  
  swapExact**FTM**ForTokensSupportingFeeOnTransferTokens
- addLiquidity**ETH** is addLiquidity**FTM**

The contract allows the intermediary to transform the calls using the 
IUniswapV2Router interface to match IHyperswapRouter.

Without the adapter, if you use the LiquidityProviderV2 contract by giving the
Hyperswap address, it will fail.