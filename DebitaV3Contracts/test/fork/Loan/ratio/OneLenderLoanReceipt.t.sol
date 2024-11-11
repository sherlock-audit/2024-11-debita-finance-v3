pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {veNFTAerodrome} from "@contracts/Non-Fungible-Receipts/veNFTS/Aerodrome/Receipt-veNFT.sol";

import {veNFTVault} from "@contracts/Non-Fungible-Receipts/veNFTS/Aerodrome/veNFTAerodrome.sol";
import {DBOFactory} from "@contracts/DebitaBorrowOffer-Factory.sol";
import {DBOImplementation} from "@contracts/DebitaBorrowOffer-Implementation.sol";
import {DLOFactory} from "@contracts/DebitaLendOfferFactory.sol";
import {DLOImplementation} from "@contracts/DebitaLendOffer-Implementation.sol";
import {DebitaV3Aggregator} from "@contracts/DebitaV3Aggregator.sol";
import {Ownerships} from "@contracts/DebitaLoanOwnerships.sol";
import {auctionFactoryDebita} from "@contracts/auctions/AuctionFactory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DynamicData} from "../../../interfaces/getDynamicData.sol";
// import ERC20
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {DebitaV3Loan} from "@contracts/DebitaV3Loan.sol";
import {DebitaIncentives} from "@contracts/DebitaIncentives.sol";
import {VotingEscrow} from "@aerodrome/VotingEscrow.sol";
import {DebitaV3Loan} from "@contracts/DebitaV3Loan.sol";
import {DutchAuction_veNFT} from "@contracts/auctions/Auction.sol";

contract DebitaAggregatorTest is Test, DynamicData {
    VotingEscrow public ABIERC721Contract;
    veNFTAerodrome public receiptContract;
    DBOFactory public DBOFactoryContract;
    DLOFactory public DLOFactoryContract;
    Ownerships public ownershipsContract;
    DebitaIncentives public incentivesContract;
    DebitaV3Aggregator public DebitaV3AggregatorContract;
    auctionFactoryDebita public auctionFactoryDebitaContract;
    DynamicData public allDynamicData;
    DebitaV3Loan public DebitaV3LoanContract;
    ERC20Mock public AEROContract;
    ERC20Mock public USDCContract;
    DLOImplementation public LendOrder;
    DBOImplementation public BorrowOrder;

    address veAERO = 0xeBf418Fe2512e7E6bd9b87a8F0f294aCDC67e6B4;
    address AERO = 0x940181a94A35A4569E4529A3CDfB74e38FD98631;
    address USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address borrower = address(0x02);
    address lender = address(this);

    uint receiptID;

    function setUp() public {
        allDynamicData = new DynamicData();
        ownershipsContract = new Ownerships();
        receiptContract = new veNFTAerodrome(veAERO, AERO);
        ABIERC721Contract = VotingEscrow(veAERO);
        incentivesContract = new DebitaIncentives();
        DBOImplementation borrowOrderImplementation = new DBOImplementation();
        DBOFactoryContract = new DBOFactory(address(borrowOrderImplementation));
        DLOImplementation proxyImplementation = new DLOImplementation();
        DLOFactoryContract = new DLOFactory(address(proxyImplementation));
        auctionFactoryDebitaContract = new auctionFactoryDebita();
        AEROContract = ERC20Mock(AERO);
        USDCContract = ERC20Mock(USDC);
        DebitaV3Loan loanInstance = new DebitaV3Loan();
        DebitaV3AggregatorContract = new DebitaV3Aggregator(
            address(DLOFactoryContract),
            address(DBOFactoryContract),
            address(incentivesContract),
            address(ownershipsContract),
            address(auctionFactoryDebitaContract),
            address(loanInstance)
        );

        ownershipsContract.setDebitaContract(
            address(DebitaV3AggregatorContract)
        );
        auctionFactoryDebitaContract.setAggregator(
            address(DebitaV3AggregatorContract)
        );
        DLOFactoryContract.setAggregatorContract(
            address(DebitaV3AggregatorContract)
        );
        DBOFactoryContract.setAggregatorContract(
            address(DebitaV3AggregatorContract)
        );

        incentivesContract.setAggregatorContract(
            address(DebitaV3AggregatorContract)
        );
        DebitaV3AggregatorContract.setValidNFTCollateral(
            address(receiptContract),
            true
        );
        deal(AERO, lender, 1000e18, false);
        deal(AERO, borrower, 1000e18, false);

        vm.startPrank(borrower);
        IERC20(AERO).approve(address(ABIERC721Contract), 100e18);
        uint id = ABIERC721Contract.createLock(10e18, 365 * 4 * 86400);
        ABIERC721Contract.approve(address(receiptContract), id);
        uint[] memory nftID = allDynamicData.getDynamicUintArray(1);
        nftID[0] = id;
        receiptContract.deposit(nftID);

        receiptID = receiptContract.lastReceiptID();

        IERC20(AERO).approve(address(DBOFactoryContract), 100e18);

        bool[] memory oraclesActivated = allDynamicData.getDynamicBoolArray(1);
        uint[] memory ltvs = allDynamicData.getDynamicUintArray(1);
        uint[] memory ratio = allDynamicData.getDynamicUintArray(1);

        address[] memory acceptedPrinciples = allDynamicData
            .getDynamicAddressArray(1);
        address[] memory acceptedCollaterals = allDynamicData
            .getDynamicAddressArray(1);
        address[] memory oraclesPrinciples = allDynamicData
            .getDynamicAddressArray(1);

        ratio[0] = 5e17;
        oraclesPrinciples[0] = address(0x0);
        acceptedPrinciples[0] = AERO;
        acceptedCollaterals[0] = address(receiptContract);
        oraclesActivated[0] = false;
        ltvs[0] = 0;
        receiptContract.approve(address(DBOFactoryContract), receiptID);
        address borrowOrderAddress = DBOFactoryContract.createBorrowOrder(
            oraclesActivated,
            ltvs,
            1400,
            864000,
            acceptedPrinciples,
            address(receiptContract),
            true,
            receiptID,
            oraclesPrinciples,
            ratio,
            address(0x0),
            1
        );
        vm.stopPrank();

        AEROContract.approve(address(DLOFactoryContract), 5e18);
        address lendOrderAddress = DLOFactoryContract.createLendOrder(
            false,
            oraclesActivated,
            false,
            ltvs,
            1000,
            8640000,
            86400,
            acceptedCollaterals,
            AERO,
            oraclesPrinciples,
            ratio,
            address(0x0),
            5e18
        );

        LendOrder = DLOImplementation(lendOrderAddress);
        BorrowOrder = DBOImplementation(borrowOrderAddress);
    }

    function testReceiptLoan() public {
        MatchOffers();
        uint[] memory indexes = allDynamicData.getDynamicUintArray(1);
        indexes[0] = 0;

        vm.startPrank(borrower);
        AEROContract.approve(address(DebitaV3LoanContract), 100e18);
        DebitaV3LoanContract.payDebt(indexes);
        veNFTAerodrome.receiptInstance[] memory holdingReceipt = receiptContract
            .getHoldingReceiptsByAddress(
                address(DebitaV3LoanContract),
                0,
                1000
            );
        veNFTAerodrome.receiptInstance[]
            memory holdingReceipt_Borrower = receiptContract
                .getHoldingReceiptsByAddress(address(borrower), 0, 1000);
        // claim the NFT
        address ownerBefore = receiptContract.ownerOf(receiptID);
        DebitaV3LoanContract.claimCollateralAsBorrower(indexes);
        address ownerAfter = receiptContract.ownerOf(receiptID);
        vm.stopPrank();

        // claim Debt
        uint balanceBefore = AEROContract.balanceOf(lender);
        DebitaV3LoanContract.claimDebt(0);
        uint balanceAfter = AEROContract.balanceOf(lender);
        veNFTAerodrome.receiptInstance[]
            memory holdingReceipt_BorrowerAfter = receiptContract
                .getHoldingReceiptsByAddress(address(borrower), 0, 1000);
        // 1000 is the apr of borrow order
        uint anualInterest = (5e18 * 1000) / 10000;
        // 86400 is 10% of 864000
        uint interestToPay = (anualInterest * 86400) / 31536000;
        uint fee = (interestToPay * 1500) / 10000;
        assertEq(balanceBefore + 5e18 + interestToPay - fee, balanceAfter);
        assertEq(ownerBefore, address(DebitaV3LoanContract));
        assertEq(ownerAfter, borrower);
        assertEq(holdingReceipt.length, 1);
        assertEq(holdingReceipt_Borrower.length, 0);
        assertEq(holdingReceipt_BorrowerAfter.length, 1);
    }

    function testExtendedLoan() public {
        MatchOffers();
        uint[] memory indexes = allDynamicData.getDynamicUintArray(1);
        indexes[0] = 0;
        vm.warp(block.timestamp + 86400);
        vm.startPrank(borrower);
        AEROContract.approve(address(DebitaV3LoanContract), 100e18);
        uint actualBlock = block.timestamp;

        DebitaV3LoanContract.payDebt(indexes);

        // claim the NFT
        address ownerBefore = receiptContract.ownerOf(receiptID);
        DebitaV3LoanContract.claimCollateralAsBorrower(indexes);
        address ownerAfter = receiptContract.ownerOf(receiptID);
        vm.stopPrank();

        uint balanceBefore = AEROContract.balanceOf(lender);
        DebitaV3LoanContract.claimDebt(0);
        uint balanceAfter = AEROContract.balanceOf(lender);

        // 1000 is the apr of borrow order
        uint anualInterest = (5e18 * 1000) / 10000;
        // 86400 is 10% of 864000
        DebitaV3Loan.LoanData memory _loanData = DebitaV3LoanContract
            .getLoanData();
        uint activeTime = actualBlock - _loanData.startedAt;
        uint interestToPay = (anualInterest * activeTime) / 31536000;
        uint fee = (interestToPay * 1500) / 10000;
        assertEq(balanceBefore + 5e18 + interestToPay - fee, balanceAfter);
        assertEq(ownerBefore, address(DebitaV3LoanContract));
        assertEq(ownerAfter, borrower);
    }

    function testDefaultLoan() public {
        MatchOffers();
        uint[] memory indexes = allDynamicData.getDynamicUintArray(1);
        indexes[0] = 0;
        vm.startPrank(borrower);
        AEROContract.approve(address(DebitaV3LoanContract), 100e18);
        vm.warp(block.timestamp + 8640010);
        console.logUint(DebitaV3LoanContract.nextDeadline());
        console.logUint(block.timestamp);
        vm.expectRevert();
        DebitaV3LoanContract.payDebt(indexes);
        vm.stopPrank();
        address ownerBefore = receiptContract.ownerOf(receiptID);
        DebitaV3LoanContract.claimCollateralAsLender(0);
        address ownerAfter = receiptContract.ownerOf(receiptID);

        assertEq(ownerBefore, address(DebitaV3LoanContract));
        assertEq(ownerAfter, lender);
    }

    function testDefaultAndAuctionCall() public {
        MatchOffers();
        uint[] memory indexes = allDynamicData.getDynamicUintArray(1);
        indexes[0] = 0;
        vm.warp(block.timestamp + 8640010);
        DebitaV3LoanContract.createAuctionForCollateral(0);
        DutchAuction_veNFT auction = DutchAuction_veNFT(
            DebitaV3LoanContract.getAuctionData().auctionAddress
        );
        DutchAuction_veNFT.dutchAuction_INFO memory auctionData = auction
            .getAuctionData();

        vm.warp(block.timestamp + (86400 * 10) + 1);

        address buyer = 0x5C235931376b21341fA00d8A606e498e1059eCc0;
        deal(AERO, buyer, 100e18);
        vm.startPrank(buyer);

        AEROContract.approve(address(auction), 100e18);
        auction.buyNFT();
        vm.stopPrank();
        address ownerOfNFT = receiptContract.ownerOf(receiptID);

        // claim sold Amount
        uint balanceBefore = AEROContract.balanceOf(lender);
        DebitaV3LoanContract.claimCollateralAsLender(0);
        uint balanceAfter = AEROContract.balanceOf(lender);
        uint fee = (15e17 * 200) / 10000;
        assertEq(balanceBefore + 15e17 - fee, balanceAfter);
        assertEq(ownerOfNFT, buyer);
        assertEq(auctionData.initAmount, 10e18);
        assertEq(auctionData.isLiquidation, true);
        assertEq(auctionData.sellingToken, AERO);
    }

    function MatchOffers() internal {
        address[] memory lendOrders = allDynamicData.getDynamicAddressArray(1);
        uint[] memory lendAmountPerOrder = allDynamicData.getDynamicUintArray(
            1
        );
        uint[] memory porcentageOfRatioPerLendOrder = allDynamicData
            .getDynamicUintArray(1);
        address[] memory principles = allDynamicData.getDynamicAddressArray(1);
        uint[] memory indexForPrinciple_BorrowOrder = allDynamicData
            .getDynamicUintArray(1);
        uint[] memory indexForCollateral_LendOrder = allDynamicData
            .getDynamicUintArray(1);
        uint[] memory indexPrinciple_LendOrder = allDynamicData
            .getDynamicUintArray(1);
        indexForPrinciple_BorrowOrder[0] = 0;
        indexForCollateral_LendOrder[0] = 0;
        indexPrinciple_LendOrder[0] = 0;

        lendOrders[0] = address(LendOrder);
        lendAmountPerOrder[0] = 5e18;
        porcentageOfRatioPerLendOrder[0] = 10000;
        principles[0] = AERO;

        address loan = DebitaV3AggregatorContract.matchOffersV3(
            lendOrders,
            lendAmountPerOrder,
            porcentageOfRatioPerLendOrder,
            address(BorrowOrder),
            principles,
            indexForPrinciple_BorrowOrder,
            indexForCollateral_LendOrder,
            indexPrinciple_LendOrder
        );

        DebitaV3LoanContract = DebitaV3Loan(loan);
    }
}
