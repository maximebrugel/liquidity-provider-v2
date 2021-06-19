# liquidity-provider-V2

This is an intermediate contract with any UniswapV2 (fork).

![schema](https://i.ibb.co/8PMNMST/Capture-d-e-cran-2021-06-19-a-09-27-34.png)

The contract allows 3 actions :
- `function addLiquidityOnlyETH(address router, address tokenB)`
<br>To add liquidity with your ETH, just give the router address and the second token of the pair (ETH-ERC20).
  
- `function addLiquidityERC20(address router, address tokenA, address tokenB, uint256 amount)`
<br>To add liquidity to a ERC20-ERC20 pair. You need to give the router address, the tokens addresses, and only the amount of the first token.
<br>The contract will manage if you already have (or not) the second token in your wallet.  
  
- `function removeLiquidity(address router, address pair, uint256 amount)`
<br>Allows to remove liquidity by giving the pair address, the router address and the amount of liquidity you want to remove.
  
## Adapters

If you have any errors with routers that change the nomenclature, please check => [adapters](contracts/adapters/adapters.md)

## Development and Testing

```sh
$ yarn
$ yarn test
```

## Gas report

![gas-report](https://i.ibb.co/FbvMt48/Capture-d-e-cran-2021-06-19-a-09-40-25.png)