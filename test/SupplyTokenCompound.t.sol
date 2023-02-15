pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "../src/SupplyTokenCompound.sol";

contract SupplyTokenCompoundTest is Test {
    address payable constant cEthContractAddress =
        payable(0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5);
    address payable constant cDAIContractAddress =
        payable(0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643);
    address payable constant DAIContractAddress =
        payable(0x6B175474E89094C44Da98b954EedeAC495271d0F);

    SupplyTokenCompound supplyTokenCompound;
    CEth constant cEthContract = CEth(cEthContractAddress);
    CErc20 constant cDAIContract = CErc20(cDAIContractAddress);
    Erc20 constant DAIContract = Erc20(DAIContractAddress);

    function setUp() public {
        supplyTokenCompound = new SupplyTokenCompound();
    }

    function testCEthName() public {
        string memory cEthName = cEthContract.name();

        emit log_named_string("CEth name: ", cEthName);
        assertEq(cEthName, "Compound Ether");
    }

    function testSupplyRedeemETH() public {
        /**
         * SUPPLY TEST
         */

        uint256 exchangeRateMantissa = cEthContract.exchangeRateCurrent();

        emit log_named_uint(
            "CEth contract exchange rate mantissa: ",
            exchangeRateMantissa
        );

        // expected CETHs for 1 Ether
        uint256 cEthTokensFor1ETH = ((10**18) * (10**18)) /
            exchangeRateMantissa;

        emit log_named_uint(
            "SupplyTokenCompound contract CETH balance before mint: ",
            cEthContract.balanceOf(address(supplyTokenCompound))
        );

        emit log_named_uint(
            "SupplyTokenCompound contract expected CETH balance: ",
            cEthTokensFor1ETH
        );

        // Mint 1 ether worth of CEth
        bool supplyCallResult = supplyTokenCompound.supplyEthToCompound{
            value: 1 ether
        }(cEthContractAddress);
        // Check call was OK
        assertTrue(supplyCallResult);

        uint256 supplyTokenCompoundCEthBalance = cEthContract.balanceOf(
            address(supplyTokenCompound)
        );

        emit log_named_uint(
            "SupplyTokenCompound CETH balance after mint: ",
            supplyTokenCompoundCEthBalance
        );

        // Check CEth balance of SupplyTokenCompound contract after mint is as expected
        assertEq(supplyTokenCompoundCEthBalance, cEthTokensFor1ETH);

        /**
         * REDEMPTION TEST
         */

        // Redeem 10 SupplyTokenCompound contract CEths
        uint256 supplyTokenCompoundETHBalanceBeforeRedemption = address(
            supplyTokenCompound
        ).balance;
        uint256 exchangeRateMantissaBeforeRedemption = cEthContract
            .exchangeRateCurrent();
        uint256 supplyTokenCompoundExpectedRedeemedEth = ((10 * (10**8)) *
            exchangeRateMantissaBeforeRedemption) / 10**18;

        uint256 redeemCallResult = supplyTokenCompound.redeemCEth(
            10 * (10**8),
            true,
            address(cEthContract)
        );
        // If call OK we have 0 error code
        assertEq(redeemCallResult, 0);

        uint256 supplyTokenCompoundCEthBalanceAfterRedemption = cEthContract
            .balanceOf(address(supplyTokenCompound));

        // Check current SupplyTokenCompound contract CEth balance is 10 CEth less of the one before redemption
        assertEq(
            supplyTokenCompoundCEthBalanceAfterRedemption,
            supplyTokenCompoundCEthBalance - (10 * (10**8))
        );

        // Check current SupplyTokenCompound contract ETH balance is higher than before redemption, and of expected value
        assertEq(
            address(supplyTokenCompound).balance,
            supplyTokenCompoundETHBalanceBeforeRedemption +
                supplyTokenCompoundExpectedRedeemedEth
        );
    }

    function testSupplyDAI() public {
        uint256 exchangeRateMantissa = cDAIContract.exchangeRateCurrent();
        // expected CDAIs for 100 DAIs
        uint256 cDAITokensFor100DAI = ((100 * 10**18) * (10**18)) /
            exchangeRateMantissa;

        emit log_named_uint(
            "CDAI contract exchange rate mantissa: ",
            exchangeRateMantissa
        );

        emit log_named_uint(
            "SupplyTokenCompound contract CDAI balance before mint: ",
            cDAIContract.balanceOf(address(supplyTokenCompound))
        );

        emit log_named_uint(
            "SupplyTokenCompound contract expected CDAI balance: ",
            cDAITokensFor100DAI
        );

        // Add 1000 DAI token balance to the SupplyTokenCompound contract
        deal(DAIContractAddress, address(supplyTokenCompound), 1000 * 10**18);

        // Mint 100 DAI worth of CDAI
        uint256 callResult = supplyTokenCompound.supplyErc20ToCompound(
            DAIContractAddress,
            cDAIContractAddress,
            100 * 10**18
        );
        // If call OK we have 0 error code
        assertEq(callResult, 0);

        emit log_named_uint(
            "SupplyTokenCompound CDAI balance after mint: ",
            cDAIContract.balanceOf(address(supplyTokenCompound))
        );

        assertEq(
            cDAIContract.balanceOf(address(supplyTokenCompound)),
            cDAITokensFor100DAI
        );
    }
}
