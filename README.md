# liquidity-provider-V2

This is an intermediate contract with any UniswapV2 (fork).

The contract allows 3 actions :
- `function addLiquidityOnlyETH(address router, address tokenB)`
To add liquidity with your ETH, just give the router address and the second token of the pair (ETH-ERC20).
  
- `function addLiquidityERC20(address router, address tokenA, address tokenB, uint256 amount)`
To add liquidity to a ERC20-ERC20 pair. You need to give the router address, the tokens addresses, and only the amount of the first token.
The contract will manage if you already have (or not) the second token in your wallet.  
  
- `function removeLiquidity(address router, address pair, uint256 amount)`
Allows to remove liquidity by giving the pair address, the router address and the amount of liquidity you want to remove.

## Development and Testing

```sh
$ yarn
$ yarn test
```

