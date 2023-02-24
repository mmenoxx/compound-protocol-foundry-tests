// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

interface Erc20 {
    function approve(address, uint256) external returns (bool);

    function transfer(address, uint256) external returns (bool);

    function balanceOf(address) external returns (uint256);
}

interface CErc20 {
    function mint(uint256) external returns (uint256);

    function borrow(uint256) external returns (uint256);

    function borrowRatePerBlock() external view returns (uint256);

    function borrowBalanceCurrent(address) external returns (uint256);

    function repayBorrow(uint256) external returns (uint256);
}

interface CEth {
    function mint() external payable;

    function borrow(uint256) external returns (uint256);

    function repayBorrow() external payable;

    function borrowBalanceCurrent(address) external returns (uint256);
}

interface Comptroller {
    function markets(address) external returns (bool, uint256);

    function enterMarkets(address[] calldata)
        external
        returns (uint256[] memory);

    function getAccountLiquidity(address)
        external
        view
        returns (
            uint256,
            uint256,
            uint256
        );
}

interface PriceFeed {
    function getUnderlyingPrice(address cToken) external view returns (uint256);
}

contract BorrowTokenCompound {
    event MyLog(string, uint256);
    CEth cEth;
    Comptroller comptroller;

    constructor(address payable _cEtherAddress, address _comptrollerAddress) {
        cEth = CEth(_cEtherAddress);
        comptroller = Comptroller(_comptrollerAddress);
    }

    // Supply ETH
    function supplyEth() external payable {
        // Supply ETH, get cETH in return
        cEth.mint{value: msg.value}();
    }

    // Supply Erc20 token
    function supplyErc20(
        address _cTokenAddress,
        address _underlyingAddress,
        uint256 _underlyingToSupplyAsCollateral
    ) external payable {
        CErc20 cToken = CErc20(_cTokenAddress);
        Erc20 underlying = Erc20(_underlyingAddress);

        // Approve transfer of underlying
        underlying.approve(_cTokenAddress, _underlyingToSupplyAsCollateral);

        // Supply underlying as collateral, get cToken in return
        uint256 error = cToken.mint(_underlyingToSupplyAsCollateral);
        require(error == 0, "CErc20.mint Error");
    }

    function enterTokenMarket(address _cTokenAddress) external payable {
        // Enter the ETH market so you can borrow another type of asset - it is not an error to enter the same market more than once
        address[] memory cTokens = new address[](1);
        cTokens[0] = _cTokenAddress;

        uint256[] memory errors = comptroller.enterMarkets(cTokens);
        if (errors[0] != 0) {
            revert("Comptroller.enterMarkets failed.");
        }
    }

    function borrowErc20(
        address _cTokenAddress,
        uint256 _numUnderlyingToBorrow,
        uint256 _underlyingDecimals
    ) public returns (uint256) {
        CErc20 cToken = CErc20(_cTokenAddress);

        // Borrow n underlying token
        uint256 callResult = cToken.borrow(
            _numUnderlyingToBorrow * 10**_underlyingDecimals
        );

        return callResult;
    }

    function erc20RepayBorrow(
        address _erc20Address,
        address _cErc20Address,
        uint256 amount
    ) public returns (bool) {
        Erc20 underlying = Erc20(_erc20Address);
        CErc20 cToken = CErc20(_cErc20Address);

        underlying.approve(_cErc20Address, amount);
        uint256 error = cToken.repayBorrow(amount);

        require(error == 0, "CErc20.repayBorrow Error");
        return true;
    }

    function borrowEth(uint256 _numWeiToBorrow) public returns (uint256) {
        // Borrow ETH
        uint256 callResult = cEth.borrow(_numWeiToBorrow);

        return callResult;
    }

    function ethRepayBorrow(uint256 _amount) public returns (bool) {
        cEth.repayBorrow{value: _amount}();
        return true;
    }

    // Need this to receive ETH when `borrowEth` executes
    receive() external payable {}
}
