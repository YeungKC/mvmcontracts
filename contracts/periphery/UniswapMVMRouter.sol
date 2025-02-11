pragma solidity =0.6.6;

import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';

import './interfaces/IUniswapV2Router02.sol';
import './interfaces/IERC20.sol';
import './libraries/UniswapV2Library.sol';

contract UniswapMVMRouter {
    address immutable router;
    uint256 constant AGE = 300;
    mapping(address => Operation) public operations;

    struct Operation {
        address asset;
        uint256 amount;
        uint256 deadline;
    }

    constructor(address _router) public {
        router = _router;
    }

    function addLiquidity(address asset, uint256 amount) public {        
        IERC20(asset).transferFrom(msg.sender, address(this), amount);

        Operation memory op = operations[msg.sender];
        if (op.asset == address(0)) {
            op.asset = asset;
            op.amount = amount;
            op.deadline = block.timestamp + AGE;
            operations[msg.sender] = op;
            return;
        }

        if (op.deadline < block.timestamp || op.asset == asset) {
            IERC20(op.asset).transfer(msg.sender, op.amount);
            IERC20(asset).transfer(msg.sender, amount);
            operations[msg.sender].asset = address(0);
            return;
        }

        IERC20(op.asset).approve(router, op.amount);
        IERC20(asset).approve(router, amount);

        uint256 amountA = op.amount;
        uint256 amountB = amount;
        uint256 liquidity;
        (amountA, amountB, liquidity) = IUniswapV2Router02(router).addLiquidity(
            op.asset, asset,
            amountA, amountB,
            amountA / 2, amountB / 2,
            msg.sender,
            block.timestamp + AGE
        );

        if (op.amount > amountA) {
            IERC20(op.asset).transfer(msg.sender, op.amount - amountA);
        }
        if (amount > amountB) {
            IERC20(asset).transfer(msg.sender, amount - amountB);
        }
        operations[msg.sender].asset = address(0);
    }

    function claim() public {
        Operation memory op = operations[msg.sender];
        if (op.asset == address(0)) {
            return;
        }
        IERC20(op.asset).transfer(msg.sender, op.amount);
    }
}
