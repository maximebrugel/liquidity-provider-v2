// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;
pragma abicoder v2;

/// @title Interface for liquidity Provider tasks
/// @notice Allow users to manage liquidity on any AMM, in a simpler way
/// @dev The AMM must be a UniswapV2 fork
/// @author Maxime Brugel
interface ILiquidityProviderV2 {
    /// @notice Add liquidity to the ETH/tokenB pool on a DEX by only providing ETH.
    /// @param router The DEX router address
    /// @param tokenB Address of the second token (ETH/tokenB)
    /// @return amountToken The amount of tokenB provided
    /// @return amountETH The amount of ETH provided
    /// @return liquidity Amount of LP token minted
    function addLiquidityOnlyETH(address router, address tokenB)
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );

    /// @notice Add liquidity to the tokenA/tokenB pool by only providing
    /// the tokenA amount. If the user balance of tokenB is not sufficient,
    /// the necessary quantity will be exchanged.
    /// @param router The DEX router address
    /// @param tokenA Address of the pair's first token
    /// @param tokenB Address of the pair's second token
    /// @param amount Amount of tokenA to provide liquidity
    /// @return amountA The amount of tokenA provided
    /// @return amountB The amount of tokenB provided
    /// @return liquidity Amount of LP token minted
    function addLiquidityERC20(
        address router,
        address tokenA,
        address tokenB,
        uint256 amount
    )
        external
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        );

    /// @notice Remove liquidity from the given pair (tokenA/tokenB)
    /// @param router The DEX router address
    /// @param pair The pair/pool address
    /// @param amount Amount of liquidity to remove
    /// @return amountA The amount of tokenA (can be ETH) removed and sent back
    /// @return amountB The amount of tokenB removed and sent back
    function removeLiquidity(
        address router,
        address pair,
        uint256 amount
    ) external returns (uint256 amountA, uint256 amountB);
}
