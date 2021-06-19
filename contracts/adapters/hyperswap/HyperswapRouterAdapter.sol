pragma solidity =0.7.6;

import "./interfaces/IHyperswapRouter02.sol";
import "./../../interfaces/IERC20Minimal.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

/// @notice adapter router to call hyperswap custom router
contract HyperswapRouterAdapter {
    IHyperswapRouter02 public router;
    address public factory;

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "UniswapV2Router: EXPIRED");
        _;
    }

    receive() external payable {}

    function deposit() public payable {}

    constructor(address _router, address _factory) public {
        router = IHyperswapRouter02(_router);
        factory = _factory;
    }

    /// @dev link with swapExactFTMForTokensSupportingFeeOnTransferTokens()
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable {
        deposit();

        router.swapExactFTMForTokensSupportingFeeOnTransferTokens{
            value: msg.value
        }(0, path, address(this), block.timestamp);

        address token = path[path.length - 1];
        IERC20Minimal(token).transfer(
            msg.sender,
            IERC20Minimal(token).balanceOf(address(this))
        );
    }

    /// @dev link with addLiquidityFTM()
    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        virtual
        ensure(deadline)
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        )
    {
        deposit();
        IERC20Minimal(token).transferFrom(
            msg.sender,
            address(this),
            amountTokenDesired
        );
        IERC20Minimal(token).approve(address(router), amountTokenDesired);

        (amountToken, amountETH, liquidity) = router.addLiquidityFTM{
            value: msg.value
        }(
            token,
            amountTokenDesired,
            amountTokenMin,
            amountETHMin,
            to,
            deadline
        );

        // refund dust eth, if any
        if (msg.value > amountETH)
            TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
    }

    /// @notice link with WFTH()
    function WETH() public view returns (address) {
        return router.WFTM();
    }
}
