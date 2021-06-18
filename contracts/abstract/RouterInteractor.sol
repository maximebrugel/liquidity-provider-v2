// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;
pragma abicoder v2;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

/// @title Contract module providing tools when interacting
/// with UniswapV2 routers
/// @author Maxime Brugel
abstract contract RouterInteractor {
    /// @notice Make sure that a router address is valid
    /// @param router The router address
    /// @dev the router and his factory must not be zero
    modifier checkRouter(address router) {
        require(
            router != address(0),
            "LiquidityProviderV2::checkRouter: router can't be zero address"
        );

        address factory = IUniswapV2Router02(router).factory();
        require(
            factory != address(0),
            "LiquidityProviderV2::checkRouter: Factory can't be zero address. Given router may not exist"
        );
        _;
    }
}
