pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "../src/BorrowTokenCompound.sol";

contract BorrowTokenCompoundTest is Test {
    address payable constant cEthContractAddress =
        payable(0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5);
    address payable constant cDAIContractAddress =
        payable(0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643);
    address payable constant DAIContractAddress =
        payable(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address constant comptrollerContractAddress =
        0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B;
    address constant priceFeedContractAddress =
        0x922018674c12a7F0D394ebEEf9B58F186CdE13c1;

    BorrowTokenCompound borrowTokenCompound;
    CEth constant cEthContract = CEth(cEthContractAddress);
    CErc20 constant cDAIContract = CErc20(cDAIContractAddress);
    Erc20 constant DAIContract = Erc20(DAIContractAddress);
    PriceFeed priceFeed = PriceFeed(priceFeedContractAddress);
    Comptroller comptroller = Comptroller(comptrollerContractAddress);

    function setUp() public {
        borrowTokenCompound = new BorrowTokenCompound(
            cEthContractAddress,
            comptrollerContractAddress
        );
    }

    function testCannotEnterUnknownMarket() public {
        vm.expectRevert("Comptroller.enterMarkets failed.");
        borrowTokenCompound.enterTokenMarket(address(0));
    }

    // Test borrowing DAI by providing ETH as collateral
    function testBorrowDAI() public {
        // Supply 1 ETH to cEth contract to have liquidity to be able to borrow DAI
        borrowTokenCompound.supplyEth{value: 1 ether}();
        // Enter the ETH market so that it can be used as collateral to borrow other tokens (in this case DAIs)
        borrowTokenCompound.enterTokenMarket(cEthContractAddress);

        // Get BorrowTokenCompound contract's total liquidity value in Compound
        (uint256 error, uint256 liquidity, uint256 shortfall) = comptroller
            .getAccountLiquidity(address(borrowTokenCompound));

        // If error code is anything other than 0, it means the call failed
        assertEq(error, 0);
        // Shortfall has to be 0 and liquidity greater than 0 to be able to borrow
        assertEq(shortfall, 0);
        assertGt(liquidity, 0);

        // Get the collateral factor (mantissa) for  ETH (just informational)
        (bool isListed, uint256 collateralFactorMantissa) = comptroller.markets(
            cEthContractAddress
        );

        emit log_named_uint(
            "ETH Collateral Factor in percentage (percentage of ETH collateral equivalent we can borrow for other tokens): ",
            (((collateralFactorMantissa * 10**3) / 10**18) * 100) / 10**3
        );

        // Check BorrowTokenCompound contract has a balance of 0 DAI on the DAI token contract before borrowing it
        assertEq(DAIContract.balanceOf(address(borrowTokenCompound)), 0);

        uint256 numUnderlyingToBorrow = 10;

        // Try to borrow numUnderlyingToBorrow DAI
        uint256 callResult = borrowTokenCompound.borrowErc20(
            address(cDAIContract),
            numUnderlyingToBorrow,
            18
        );

        // Check call was OK
        // If error code is anything other than 0, it means the call failed on cToken contract
        assertEq(callResult, 0);

        // Get the underlying token (DAI) borrow balance, for the BorrowTokenCompound contract, for the DAI CToken contract
        uint256 BorrowTokenCompoundDAIBorrowBalance = (
            cDAIContract.borrowBalanceCurrent(address(borrowTokenCompound))
        ) / 10**18;

        emit log_named_uint(
            "Current underlying token (DAI) borrowed amount for BorrowTokenCompound contract: ",
            BorrowTokenCompoundDAIBorrowBalance
        );
        // Check that the amount of borrowed underlying token (10 DAI) is equal to the current BorrowTokenCompound contract DAI borrow balance
        assertEq(numUnderlyingToBorrow, BorrowTokenCompoundDAIBorrowBalance);
        // Also check that BorrowTokenCompound contract now has a balance of 10 DAI on the DAI token contract
        assertEq(
            DAIContract.balanceOf(address(borrowTokenCompound)),
            10 * 10**18
        );
    }

    // Test repay DAI borrow
    function testRepayBorrowDAI() public {
        // Supply 1 ETH to cEth contract to have liquidity to be able to borrow DAI
        borrowTokenCompound.supplyEth{value: 1 ether}();
        // Enter the ETH market so that it can be used as collateral to borrow other tokens (in this case DAIs)
        borrowTokenCompound.enterTokenMarket(cEthContractAddress);

        // Try to borrow 10 DAI
        uint256 callResultBorrow = borrowTokenCompound.borrowErc20(
            address(cDAIContract),
            10,
            18
        );

        // Check that call was OK
        assertEq(callResultBorrow, 0);

        // Check that BorrowTokenCompound contract now has a balance of 10 DAI on the DAI token contract
        assertEq(
            DAIContract.balanceOf(address(borrowTokenCompound)),
            10 * 10**18
        );

        // Repay the whole borrow
        bool callResult = borrowTokenCompound.erc20RepayBorrow(
            DAIContractAddress,
            cDAIContractAddress,
            10 * 10**18
        );

        // Check that call was OK
        assertTrue(callResult);

        // Check that BorrowTokenCompound contract now has a balance of 0 DAI on the DAI token contract after repaying the borrow
        assertEq(DAIContract.balanceOf(address(borrowTokenCompound)), 0);
    }

    // Test borrowing ETH by providing DAI as collateral
    function testBorrowETH() public {
        // First thing first add 100 DAI balance to the BorrowTokenCompound contract (so it will be then able to supply them to the Compound protocol)
        deal(DAIContractAddress, address(borrowTokenCompound), 100 * 10**18);

        // Supply 100 DAI so we have liquidity to then borrow ETH
        borrowTokenCompound.supplyErc20(
            cDAIContractAddress,
            DAIContractAddress,
            100 * 10**18
        );
        // Enter the DAI market so that it can be used as collateral to borrow other tokens (in this case ETH)
        borrowTokenCompound.enterTokenMarket(cDAIContractAddress);

        // Get BorrowTokenCompound contract's total liquidity value in Compound
        (uint256 error, uint256 liquidity, uint256 shortfall) = comptroller
            .getAccountLiquidity(address(borrowTokenCompound));

        // If error code is anything other than 0, it means the call failed
        assertEq(error, 0);
        // Shortfall has to be 0 and liquidity greater than 0 to be able to borrow
        assertEq(shortfall, 0);
        assertGt(liquidity, 0);

        // Get the collateral factor (mantissa) for DAI (just informational)
        (bool isListed, uint256 collateralFactorMantissa) = comptroller.markets(
            cDAIContractAddress
        );

        emit log_named_uint(
            "DAI Collateral Factor in percentage (percentage of DAI collateral equivalent we can borrow for other tokens): ",
            (((collateralFactorMantissa * 10**3) / 10**18) * 100) / 10**3
        );

        // Get BorrowTokenCompound contract's ETH balance before borrowing ETH
        uint256 BorrowTokenCompoundETHBalanceBeforeBorrow = address(
            borrowTokenCompound
        ).balance;

        uint256 numETHToBorrow = 0.001 ether;

        // Try to borrow numETHToBorrow ETH
        uint256 callResult = borrowTokenCompound.borrowEth(numETHToBorrow);

        // Check call was OK
        // If error code is anything other than 0, it means the call failed on cToken contract
        assertEq(callResult, 0);

        // Get BorrowTokenCompound contract's ETH balance after borrowing ETH
        uint256 BorrowTokenCompoundETHBalanceAfterBorrow = address(
            borrowTokenCompound
        ).balance;

        // Check that BorrowTokenCompound contract's ETH balance after borrowing ETH is equal to its balance before borrowing ETH
        // plus the amount of ETH that it borrowed
        assertEq(
            BorrowTokenCompoundETHBalanceAfterBorrow,
            BorrowTokenCompoundETHBalanceBeforeBorrow + numETHToBorrow
        );

        // Get the ETH borrow balance (in Wei), for the BorrowTokenCompound contract, for the ETH CToken contract
        uint256 BorrowTokenCompoundETHBorrowBalance = (
            cEthContract.borrowBalanceCurrent(address(borrowTokenCompound))
        );

        emit log_named_uint(
            "Current ETH borrowed amount for BorrowTokenCompound contract: ",
            BorrowTokenCompoundETHBorrowBalance
        );
        // Check that the current BorrowTokenCompound contract ETH borrow balance is equal to the amount of borrowed ETH (0.001 ETH)
        assertEq(BorrowTokenCompoundETHBorrowBalance, numETHToBorrow);
    }

    // Test repay ETH borrow
    function testRepayBorrowETH() public {
        // First thing first add 100 DAI balance to the BorrowTokenCompound contract (so it will be then able to supply them to the Compound protocol)
        deal(DAIContractAddress, address(borrowTokenCompound), 100 * 10**18);

        // Supply 100 DAI so we have liquidity to then borrow ETH
        borrowTokenCompound.supplyErc20(
            cDAIContractAddress,
            DAIContractAddress,
            100 * 10**18
        );
        // Enter the DAI market so that it can be used as collateral to borrow other tokens (in this case ETH)
        borrowTokenCompound.enterTokenMarket(cDAIContractAddress);

        // Get BorrowTokenCompound contract's ETH balance before borrowing ETH
        uint256 BorrowTokenCompoundETHBalanceBeforeBorrow = address(
            borrowTokenCompound
        ).balance;

        uint256 numETHToBorrow = 0.001 ether;

        // Try to borrow numETHToBorrow ETH
        uint256 callResultBorrow = borrowTokenCompound.borrowEth(
            numETHToBorrow
        );

        // Check call was OK
        // If error code is anything other than 0, it means the call failed on cToken contract
        assertEq(callResultBorrow, 0);

        // Repay the whole borrow
        bool callResult = borrowTokenCompound.ethRepayBorrow(0.001 ether);

        // Check that call was OK
        assertTrue(callResult);

        // Check that BorrowTokenCompound contract now has a balance of ETH equals to its balance before borrowing ETH
        assertEq(
            address(borrowTokenCompound).balance,
            BorrowTokenCompoundETHBalanceBeforeBorrow
        );
    }
}
