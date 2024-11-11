pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {veNFTVault} from "@contracts/Non-Fungible-Receipts/veNFTS/Equalizer/veNFTEqualizer.sol";

import {veNFTEqualizer} from "@contracts/Non-Fungible-Receipts/veNFTS/Equalizer/Receipt-veNFT.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {VotingEscrow} from "@aerodrome/VotingEscrow.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract CounterTestEqualizer is Test {
    VotingEscrow public ABIERC721Contract;
    veNFTEqualizer public receiptContract;
    veNFTVault[] public veNFTVaultContract = new veNFTVault[](3);
    ERC20Mock public TOKEN;
    address[] vaultAddress = new address[](3);
    uint[] nftID = new uint[](3);
    uint[] receiptID = new uint[](3);

    address veAERO = 0x28c9C71c776a1203000B56C0Cca48BEf1cd51C53;
    address AERO = 0x54016a4848a38f257B6E96331F7404073Fd9c32C;
    address borrower = address(0x04);

    function setUp() public {
        vm.startPrank(borrower);
        ABIERC721Contract = VotingEscrow(veAERO);
        TOKEN = ERC20Mock(AERO);
        receiptContract = new veNFTEqualizer(address(ABIERC721Contract), AERO);

        deal(AERO, borrower, 1000e18, true);
        TOKEN.approve(address(ABIERC721Contract), 1000e18);

        for (uint i = 0; i < 3; i++) {
            uint id = ABIERC721Contract.create_lock(100e18, 22 * 7 * 86400);
            ABIERC721Contract.approve(address(receiptContract), id);
            nftID[i] = id;
        }

        receiptContract.deposit(nftID);

        for (uint i = 0; i < 3; i++) {
            receiptID[i] = receiptContract.lastReceiptID() - 2 + i;
            address vault = receiptContract.s_ReceiptID_to_Vault(receiptID[i]);
            vaultAddress[i] = vault;
            veNFTVaultContract[i] = (veNFTVault(vault));
        }
        vm.stopPrank();
    }

    function testWithdraw() public {
        veNFTEqualizer.receiptInstance[]
            memory receiptCalculated = receiptContract.getDataFromUser(
                borrower,
                0,
                1000
            );

        vm.startPrank(borrower);
        receiptContract.approve(address(veNFTVaultContract[0]), receiptID[0]);
        veNFTVaultContract[0].withdraw();
        address owner = ABIERC721Contract.ownerOf(nftID[0]);
        assertEq(owner, borrower);
        vm.stopPrank();
    }

    function testFailWithdrawSecondTry() public {
        vm.startPrank(borrower);

        vm.expectRevert("No attached nft");

        receiptContract.approve(address(veNFTVaultContract[0]), receiptID[0]);
        veNFTVaultContract[0].withdraw();
        veNFTVaultContract[0].withdraw();
        vm.stopPrank();
    }

    function testChangeManagerAndInteract() public {
        vm.startPrank(borrower);

        address newManager = address(1);
        veNFTVaultContract[0].changeManager(newManager);

        assertEq(veNFTVaultContract[0].managerAddress(), newManager);
        receiptContract.approve(address(veNFTVaultContract[0]), receiptID[0]);
        veNFTVaultContract[0].withdraw();
        assertEq(veNFTVaultContract[0].attached_NFTID(), 0);
        vm.stopPrank();
    }

    function testFailChangeManagerAndInteract() public {
        vm.startPrank(borrower);
        address newManager = address(1);
        veNFTVaultContract[0].changeManager(newManager);
        assertEq(veNFTVaultContract[0].managerAddress(), newManager);
        vm.stopPrank();
        vm.startPrank(newManager);
        receiptContract.approve(address(veNFTVaultContract[0]), receiptID[0]);
        veNFTVaultContract[0].withdraw();
        vm.stopPrank();
    }

    function testChangeManagerReturn() public {
        vm.startPrank(borrower);

        address newManager = address(1);
        veNFTVaultContract[0].changeManager(newManager);
        assertEq(veNFTVaultContract[0].managerAddress(), newManager);
        vm.stopPrank();
        vm.startPrank(newManager);
        veNFTVaultContract[0].changeManager(address(this));
        vm.stopPrank();
        assertEq(veNFTVaultContract[0].managerAddress(), address(this));
    }

    function testWithdrawAfterExpiring() public {
        vm.startPrank(borrower);

        receiptContract.approve(address(veNFTVaultContract[0]), receiptID[0]);
        vm.warp(block.timestamp + (365 * 4 * 86400 * 2));
        veNFTVaultContract[0].withdraw();
        address owner = ABIERC721Contract.ownerOf(nftID[0]);
        assertEq(owner, borrower);
        vm.stopPrank();
    }

    function testWithdrawAndDepositAgain() public {
        vm.startPrank(borrower);
        uint[] memory newNFTID = getDynamicUintArray(20);
        address[] memory _vaultAddress = getDynamicAddressArray(20);
        veNFTVault[] memory _veNFTVaultContract = new veNFTVault[](20);
        uint[] memory _receiptID = new uint[](20);
        for (uint i = 0; i < 20; i++) {
            uint id = ABIERC721Contract.create_lock(1e18, 26 * 7 * 86400);
            ABIERC721Contract.approve(address(receiptContract), id);

            newNFTID[i] = id;
        }

        receiptContract.deposit(newNFTID);

        for (uint i = 0; i < 20; i++) {
            _receiptID[i] = receiptContract.lastReceiptID() - 19 + i;
            address vault = receiptContract.s_ReceiptID_to_Vault(_receiptID[i]);
            _vaultAddress[i] = vault;
            _veNFTVaultContract[i] = (veNFTVault(vault));
        }
        // withdraw
        receiptContract.approve(address(_veNFTVaultContract[1]), _receiptID[1]);
        _veNFTVaultContract[1].withdraw();

        receiptContract.approve(address(_veNFTVaultContract[6]), _receiptID[6]);
        _veNFTVaultContract[6].withdraw();

        receiptContract.approve(
            address(_veNFTVaultContract[19]),
            _receiptID[19]
        );
        _veNFTVaultContract[19].withdraw();

        veNFTEqualizer.receiptInstance[]
            memory receiptCalculated = receiptContract.getDataFromUser(
                borrower,
                0,
                1000
            );
        vm.stopPrank();
    }

    function getDynamicUintArray(
        uint256 x
    ) public pure returns (uint[] memory) {
        uint[] memory nftsID = new uint[](x);
        return nftsID;
    }

    function getDynamicAddressArray(
        uint256 x
    ) public pure returns (address[] memory) {
        address[] memory nftsID = new address[](x);
        return nftsID;
    }
}
