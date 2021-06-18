// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;
pragma abicoder v2;

import "./interfaces/ILiquidityProviderV2.sol";
import "./interfaces/IERC20Minimal.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "./abstract/RouterInteractor.sol";

/// @author Maxime Brugel
contract LiquidityProviderV2 is ILiquidityProviderV2, RouterInteractor {
    using SafeMath for uint256;

    constructor() {}

    receive() external payable {}

    function deposit() public payable {}

    /// @inheritdoc ILiquidityProviderV2
    function addLiquidityOnlyETH(address router, address tokenB)
        external
        payable
        override
        checkRouter(router)
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        )
    {
        deposit();

        // Swap half of the deposited ETH for some tokenB
        amountETH = SafeMath.div(msg.value, 2);
        amountToken = _swapEthForTokenAndApprove(router, amountETH, tokenB);

        (amountToken, amountETH, liquidity) = IUniswapV2Router02(router)
        .addLiquidityETH{value: amountETH}(
            tokenB,
            amountToken,
            0,
            0,
            msg.sender,
            block.timestamp
        );
    }

    /// @inheritdoc ILiquidityProviderV2
    function addLiquidityERC20(
        address router,
        address tokenA,
        address tokenB,
        uint256 amount
    )
        external
        override
        checkRouter(router)
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        )
    {
        IERC20Minimal(tokenA).transferFrom(msg.sender, address(this), amount);

        // Transfer tokenB from user and manage insufficient balance
        (amountA, amountB) = _transferTokenB(router, tokenA, tokenB, amount);

        // Add liquidity with the right amounts
        (amountA, amountB, liquidity) = _addLiquidityERC20(
            router,
            tokenA,
            tokenB,
            amountA,
            amountB
        );

        IERC20Minimal(tokenA).transfer(msg.sender, IERC20Minimal(tokenA).balanceOf(address(this)));
    }

    /// @inheritdoc ILiquidityProviderV2
    function removeLiquidity(
        address router,
        address pair,
        uint256 amount
    )
        external
        override
        checkRouter(router)
        returns (uint256 amountA, uint256 amountB)
    {
        IUniswapV2Pair(pair).transferFrom(msg.sender, address(this), amount);
        IUniswapV2Pair(pair).approve(router, amount);

        address weth = IUniswapV2Router02(router).WETH();
        address token0 = IUniswapV2Pair(pair).token0();
        address token1 = IUniswapV2Pair(pair).token1();

        if (token0 == weth) {
            (amountA, amountB) = IUniswapV2Router02(router).removeLiquidityETH(
                token1,
                amount,
                0,
                0,
                msg.sender,
                block.timestamp
            );
        } else if (token1 == weth) {
            (amountA, amountB) = IUniswapV2Router02(router).removeLiquidity(
                token0,
                token1,
                amount,
                0,
                0,
                msg.sender,
                block.timestamp
            );
        } else {
            (amountA, amountB) = IUniswapV2Router02(router).removeLiquidity(
                token0,
                token1,
                amount,
                0,
                0,
                msg.sender,
                block.timestamp
            );
        }
    }

    /// @notice Swap ETH for tokenB, and approve router
    /// for spending the received tokenB.
    /// @dev Eth must be deposited in the contract
    /// @param router The DEX router address
    /// @param amountETH The amount to swap for tokenB
    /// @param tokenB The tokenB address
    /// @return tokenAmount The amount of tokenB received
    function _swapEthForTokenAndApprove(
        address router,
        uint256 amountETH,
        address tokenB
    ) internal returns (uint256 tokenAmount) {
        address[] memory dexPairPath = new address[](2);
        dexPairPath[0] = IUniswapV2Router02(router).WETH();
        dexPairPath[1] = tokenB;

        tokenAmount = IERC20Minimal(tokenB).balanceOf(address(this));

        IUniswapV2Router02(router)
            .swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: amountETH
        }(0, dexPairPath, address(this), block.timestamp);

        tokenAmount = SafeMath.sub(
            IERC20Minimal(tokenB).balanceOf(address(this)),
            tokenAmount
        );

        IERC20Minimal(tokenB).approve(router, tokenAmount);
    }

    /// @notice Transfer from the user the necessary amount of tokenB for
    /// the given amount of tokenA. If the user balance of tokenB is not sufficient,
    /// we will rebalance the amount of tokenA and tokenB.
    /// @param router The DEX router address
    /// @param tokenA Address of the pair's first token
    /// @param tokenB Address of the pair's second token
    /// @param amount Amount of tokenA to define tokenB
    /// @return amountA rebalanced amount of tokenA
    /// @return amountB rebalanced amount of tokenB
    function _transferTokenB(
        address router,
        address tokenA,
        address tokenB,
        uint256 amount
    ) internal returns (uint256 amountA, uint256 amountB) {
        //  Path : tokenA => tokenB
        address[] memory tokenAToBPath = new address[](2);
        tokenAToBPath[0] = tokenA;
        tokenAToBPath[1] = tokenB;

        // Define the amount of tokenB that we need to add liquidity with
        // the given amount of tokenA
        uint256 neededAmountB = IUniswapV2Router02(router).getAmountsOut(
            amount,
            tokenAToBPath
        )[tokenAToBPath.length - 1];

        uint256 userBalanceTokenB = IERC20Minimal(tokenB).balanceOf(msg.sender);

        // Scenario where the user needs more tokenB
        if (userBalanceTokenB < neededAmountB) {
            // transfer the current balance
            IERC20Minimal(tokenB).transferFrom(
                msg.sender,
                address(this),
                userBalanceTokenB
            );

            // Amount of tokenB missing by the user to add liquidity
            uint256 missingAmountB = SafeMath.sub(
                neededAmountB,
                userBalanceTokenB
            );

            /*
             * Basically, we are defining the amount of tokenA to swap
             * for half of the missing tokenB
             */
            uint256 halfMissingAmountB = SafeMath.div(missingAmountB, 2);
            uint256 amountAExcess = IUniswapV2Router02(router).getAmountsIn(
                halfMissingAmountB,
                tokenAToBPath
            )[0];

            IERC20Minimal(tokenA).approve(router, amountAExcess);
            IUniswapV2Router02(router)
                .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                amountAExcess,
                halfMissingAmountB,
                tokenAToBPath,
                address(this),
                block.timestamp
            );

            amountA = SafeMath.sub(amount, amountAExcess);
            amountB = SafeMath.add(userBalanceTokenB, halfMissingAmountB);
        } else {
            // The user has enough tokenB
            IERC20Minimal(tokenB).transferFrom(
                msg.sender,
                address(this),
                neededAmountB
            );
            amountA = amount;
            amountB = neededAmountB;
        }
    }

    /// @dev Approve tokens and add liquidity
    /// @param router The DEX router address
    /// @param tokenA Address of the pair's first token
    /// @param tokenB Address of the pair's second token
    /// @param amountA Amount of tokenA to provide liquidity
    /// @param amountB Amount of tokenB to provide liquidity
    /// @return amountAProvided The amount of tokenA provided
    /// @return amountBProvided The amount of tokenB provided
    /// @return liquidity Amount of LP token minted
    function  _addLiquidityERC20(
        address router,
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    )
        internal
        returns (
            uint256 amountAProvided,
            uint256 amountBProvided,
            uint256 liquidity
        )
    {
        IERC20Minimal(tokenA).approve(router, amountA);
        IERC20Minimal(tokenB).approve(router, amountB);

        (amountAProvided, amountBProvided, liquidity) = IUniswapV2Router02(
            router
        ).addLiquidity(
            tokenA,
            tokenB,
            amountA,
            amountB,
            0,
            0,
            msg.sender,
            block.timestamp
        );
    }
}
