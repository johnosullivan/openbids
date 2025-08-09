// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {AuctionUpgradeable} from "../src/AuctionUpgradeable.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    constructor() ERC20("TestToken", "TT") {}
    function mint(address to, uint256 amount) external { _mint(to, amount); }
}

contract ReentrantBidder {
    AuctionUpgradeable public auction;
    uint256 public auctionId;

    function setTarget(AuctionUpgradeable _auction, uint256 _auctionId) external {
        auction = _auction;
        auctionId = _auctionId;
    }

    receive() external payable {
        // Attempt to reenter withdraw; should revert with NothingToWithdraw and be ignored
        try auction.withdraw(auctionId) {} catch {}
    }

    function bidETH(uint256 _auctionId, string calldata cid) external payable {
        auction.placeBid{value: msg.value}(_auctionId, cid);
    }
}

contract ReentrantToken is ERC20 {
    AuctionUpgradeable public auction;
    uint256 public auctionId;
    bool public enabled;

    constructor() ERC20("ReentrantToken", "RNT") {}

    function setReenterTarget(AuctionUpgradeable _auction, uint256 _auctionId, bool _enabled) external {
        auction = _auction;
        auctionId = _auctionId;
        enabled = _enabled;
    }

    function mint(address to, uint256 amount) external { _mint(to, amount); }

    function _update(address from, address to, uint256 value) internal override {
        if (enabled && from == address(auction) && to != address(0)) {
            // Swallow any revert
            try auction.withdraw(auctionId) {} catch {}
        }
        super._update(from, to, value);
    }
}

// --- UUPS Upgrade tests ---
contract AuctionUpgradeableV2 is AuctionUpgradeable {
    string public versionName;
    function initializeV2(string memory v) public reinitializer(2) { versionName = v; }
    function getVersion() external view returns (string memory) { return versionName; }
}

contract AuctionUpgradeableTest is Test {
    AuctionUpgradeable private auction;
    TestToken private token;

    address private owner = address(this);
    address private beneficiary = address(0xBEEF);
    address private alice = address(0xA11CE);
    address private bob = address(0xB0B);

    function setUp() public {
        // Deploy implementation and proxy with initializer
        AuctionUpgradeable impl = new AuctionUpgradeable();
        bytes memory initData = abi.encodeCall(AuctionUpgradeable.initialize, (owner));
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        auction = AuctionUpgradeable(payable(address(proxy)));

        // Deploy ERC20 for token auctions
        token = new TestToken();

        // Fund participants
        vm.deal(alice, 1000 ether);
        vm.deal(bob, 1000 ether);
        token.mint(alice, 1_000_000 ether);
        token.mint(bob, 1_000_000 ether);
    }

    function _createETHAuction(uint256 reserve) internal returns (uint256 auctionId) {
        uint64 nowTs = uint64(block.timestamp);
        auctionId = auction.createAuction(payable(beneficiary), nowTs, nowTs + 1 days, reserve);
    }

    function _createTokenAuction(uint256 reserve) internal returns (uint256 auctionId) {
        uint64 nowTs = uint64(block.timestamp);
        auctionId = auction.createAuctionWithToken(payable(beneficiary), nowTs, nowTs + 1 days, reserve, address(token));
    }

    function testETHAuctionFlow_bid_withdraw_finalize() public {
        uint256 auctionId = _createETHAuction(1 ether);

        vm.prank(alice);
        auction.placeBid{value: 1 ether}(auctionId, "cid-alice");

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(AuctionUpgradeable.BidTooLow.selector, 1 ether));
        auction.placeBid{value: 1 ether}(auctionId, "cid-bob-low");

        vm.prank(bob);
        auction.placeBid{value: 1 ether + 1}(auctionId, "cid-bob");

        assertEq(auction.getPendingReturns(auctionId, alice), 1 ether);
        uint256 aliceBefore = alice.balance;
        vm.prank(alice);
        auction.withdraw(auctionId);
        assertEq(alice.balance, aliceBefore + 1 ether);
        assertEq(auction.getPendingReturns(auctionId, alice), 0);

        vm.warp(block.timestamp + 2 days);
        uint256 benBefore = beneficiary.balance;
        auction.finalize(auctionId);
        assertEq(beneficiary.balance, benBefore + (1 ether + 1));

        assertFalse(auction.isActive(auctionId));
    }

    function testTokenAuctionFlow_bid_withdraw_finalize() public {
        uint256 auctionId = _createTokenAuction(100 ether);

        // Wrong path must revert
        vm.prank(alice);
        vm.expectRevert(bytes("Use token bid"));
        auction.placeBid{value: 100 ether}(auctionId, "cid-eth-wrong");

        vm.prank(alice); token.approve(address(auction), type(uint256).max);
        vm.prank(bob);   token.approve(address(auction), type(uint256).max);

        vm.prank(alice); auction.placeBidToken(auctionId, "cid-alice", 100 ether);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(AuctionUpgradeable.BidTooLow.selector, 100 ether));
        auction.placeBidToken(auctionId, "cid-bob-low", 100 ether);

        vm.prank(bob);   auction.placeBidToken(auctionId, "cid-bob", 100 ether + 1);

        assertEq(auction.getPendingReturns(auctionId, alice), 100 ether);
        uint256 aliceTokBefore = token.balanceOf(alice);
        vm.prank(alice);
        auction.withdraw(auctionId);
        assertEq(token.balanceOf(alice), aliceTokBefore + 100 ether);
        assertEq(auction.getPendingReturns(auctionId, alice), 0);

        vm.warp(block.timestamp + 2 days);
        uint256 benTokBefore = token.balanceOf(beneficiary);
        auction.finalize(auctionId);
        assertEq(token.balanceOf(beneficiary), benTokBefore + (100 ether + 1));
    }

    function testCreateAuction_InvalidParams() public {
        uint64 nowTs = uint64(block.timestamp);
        // zero beneficiary
        vm.expectRevert(bytes("Invalid beneficiary"));
        auction.createAuction(payable(address(0)), nowTs, nowTs + 1 days, 0);
        // end <= start
        vm.expectRevert(bytes("Invalid time window"));
        auction.createAuction(payable(beneficiary), nowTs + 1 days, nowTs + 1 days, 0);
        // start in past
        vm.expectRevert(bytes("Start time in past"));
        auction.createAuction(payable(beneficiary), nowTs - 1, nowTs + 1 days, 0);
    }

    function testCreateAuctionWithToken_InvalidParams() public {
        uint64 nowTs = uint64(block.timestamp);
        // zero token
        vm.expectRevert(bytes("Token required"));
        auction.createAuctionWithToken(payable(beneficiary), nowTs, nowTs + 1 days, 0, address(0));
    }

    function testPlaceBid_Reverts_WhenNotActive() public {
        uint64 nowTs = uint64(block.timestamp);
        uint256 auctionId = auction.createAuction(payable(beneficiary), nowTs + 1 days, nowTs + 2 days, 1);
        // before start
        vm.expectRevert(AuctionUpgradeable.AuctionNotStarted.selector);
        auction.placeBid{value: 1}(auctionId, "cid");
        // after end
        vm.warp(block.timestamp + 3 days);
        vm.expectRevert(AuctionUpgradeable.AuctionEnded.selector);
        auction.placeBid{value: 2}(auctionId, "cid2");
    }

    function testFinalize_Reverts_WhileActive_And_AlreadyFinalized() public {
        uint256 auctionId = _createETHAuction(1);
        // finalize before end
        vm.expectRevert(abi.encodeWithSelector(AuctionUpgradeable.AuctionStillActive.selector, uint64(block.timestamp + 1 days), block.timestamp));
        auction.finalize(auctionId);
        // end and finalize once
        vm.warp(block.timestamp + 2 days);
        auction.finalize(auctionId);
        // second time reverts
        vm.expectRevert(AuctionUpgradeable.AlreadyFinalized.selector);
        auction.finalize(auctionId);
    }

    function testNonexistentAuctionReverts() public {
        uint256 nonexistent = 9999;
        vm.expectRevert(AuctionUpgradeable.AuctionDoesNotExist.selector);
        auction.placeBid{value: 1}(nonexistent, "cid");
        vm.expectRevert(AuctionUpgradeable.AuctionDoesNotExist.selector);
        auction.finalize(nonexistent);
        vm.expectRevert(AuctionUpgradeable.AuctionDoesNotExist.selector);
        auction.getAuction(nonexistent);
        vm.expectRevert(AuctionUpgradeable.AuctionDoesNotExist.selector);
        auction.getAuctionToken(nonexistent);
    }

    function testMultipleAuctionsIndependentState() public {
        uint256 a1 = _createETHAuction(1 ether);
        uint256 a2 = _createETHAuction(2 ether);
        vm.prank(alice); auction.placeBid{value: 1 ether}(a1, "a1-alice");
        vm.prank(bob);   auction.placeBid{value: 2 ether}(a2, "a2-bob");
        // Ensure bids don't cross
        (, , , , , , uint256 hb1,,) = auction.getAuction(a1);
        (, , , , , , uint256 hb2,,) = auction.getAuction(a2);
        assertEq(hb1, 1 ether);
        assertEq(hb2, 2 ether);
    }

    
    function testOnlyOwnerCanUpgrade() public {

        // --- UUPS Upgrade tests ---
        // Deploy V2 impl
        AuctionUpgradeableV2 v2 = new AuctionUpgradeableV2();
        // Non-owner cannot upgrade
        address attacker = address(0xBAD);
        vm.prank(attacker);
        vm.expectRevert(); // OZ UUPS checks + onlyOwner
        AuctionUpgradeable(address(auction)).upgradeTo(address(v2));

        // Owner upgrades
        AuctionUpgradeable(address(auction)).upgradeTo(address(v2));
        // Call new initializer
        AuctionUpgradeableV2(address(auction)).initializeV2("v2");
        assertEq(keccak256(bytes(AuctionUpgradeableV2(address(auction)).getVersion())), keccak256("v2"));
    }

    function testOwnerSetByInitializer() public {
        // Deploy a fresh proxy with a different owner
        AuctionUpgradeable impl = new AuctionUpgradeable();
        address newOwner = address(0x1234);
        bytes memory initData = abi.encodeCall(AuctionUpgradeable.initialize, (newOwner));
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        AuctionUpgradeable a = AuctionUpgradeable(address(proxy));
        assertEq(a.owner(), newOwner);
    }

    function testMismatchedBidFunctions() public {
        uint256 ethAuctionId = _createETHAuction(0);
        uint256 tokAuctionId = _createTokenAuction(0);

        vm.expectRevert(bytes("Use native bid"));
        auction.placeBidToken(ethAuctionId, "cid", 1);

        vm.expectRevert(bytes("Use token bid"));
        auction.placeBid{value: 1 ether}(tokAuctionId, "cid");
    }

    function testWithdrawReentrancyETH() public {
        uint256 auctionId = _createETHAuction(1 ether);

        ReentrantBidder rb = new ReentrantBidder();
        rb.setTarget(auction, auctionId);
        vm.deal(address(rb), 10 ether);
        vm.prank(address(rb));
        rb.bidETH{value: 2 ether}(auctionId, "cid-rb");

        vm.prank(bob);
        auction.placeBid{value: 2 ether + 1}(auctionId, "cid-bob");

        assertEq(auction.getPendingReturns(auctionId, address(rb)), 2 ether);
        uint256 beforeBal = address(rb).balance;
        vm.prank(address(rb));
        auction.withdraw(auctionId);
        assertEq(address(rb).balance, beforeBal + 2 ether);
        assertEq(auction.getPendingReturns(auctionId, address(rb)), 0);
    }

    function testWithdrawReentrancyToken() public {
        ReentrantToken rTok = new ReentrantToken();
        uint64 nowTs = uint64(block.timestamp);
        uint256 auctionId = auction.createAuctionWithToken(payable(beneficiary), nowTs, nowTs + 1 days, 100 ether, address(rTok));

        rTok.mint(alice, 1000 ether);
        rTok.mint(bob, 1000 ether);
        vm.prank(alice); rTok.approve(address(auction), type(uint256).max);
        vm.prank(bob);   rTok.approve(address(auction), type(uint256).max);

        vm.prank(alice); auction.placeBidToken(auctionId, "cid-a", 200 ether);
        vm.prank(bob);   auction.placeBidToken(auctionId, "cid-b", 200 ether + 1);

        rTok.setReenterTarget(auction, auctionId, true);

        uint256 before = rTok.balanceOf(alice);
        vm.prank(alice);
        auction.withdraw(auctionId);
        assertEq(rTok.balanceOf(alice), before + 200 ether);
        assertEq(auction.getPendingReturns(auctionId, alice), 0);
    }

    /*function testFuzz_ETHBidOrdering(uint96 reserveRaw, uint96 b1Raw, uint96 b2Raw) public {
        uint256 reserve = bound(uint256(reserveRaw), 0, 1_000_000 ether);
        uint256 b1 = bound(uint256(b1Raw), 0, 1_000_000 ether);
        uint256 b2 = bound(uint256(b2Raw), 0, 1_000_000 ether);

        uint256 auctionId = _createETHAuction(reserve);

        if (b1 < reserve) {
            vm.prank(alice);
            vm.expectRevert(abi.encodeWithSelector(AuctionUpgradeable.BidTooLow.selector, 0));
            auction.placeBid{value: b1}(auctionId, "cid-a");
            return;
        }

        vm.prank(alice);
        auction.placeBid{value: b1}(auctionId, "cid-a");

        if (b2 <= b1) {
            vm.prank(bob);
            vm.expectRevert(abi.encodeWithSelector(AuctionUpgradeable.BidTooLow.selector, b1));
            auction.placeBid{value: b2}(auctionId, "cid-b");
        } else {
            vm.prank(bob);
            auction.placeBid{value: b2}(auctionId, "cid-b");
            assertEq(auction.getPendingReturns(auctionId, alice), b1);
            (,,,,, , uint256 highestBid,,) = auction.getAuction(auctionId);
            assertEq(highestBid, b2);
        }
    }*/

    /*function testFuzz_TokenBidOrdering(uint96 reserveRaw, uint96 b1Raw, uint96 b2Raw) public {
        uint256 reserve = bound(uint256(reserveRaw), 0, 1_000_000 ether);
        uint256 b1 = bound(uint256(b1Raw), 0, 1_000_000 ether);
        uint256 b2 = bound(uint256(b2Raw), 0, 1_000_000 ether);

        uint256 auctionId = _createTokenAuction(reserve);
        vm.prank(alice); token.approve(address(auction), type(uint256).max);
        vm.prank(bob);   token.approve(address(auction), type(uint256).max);

        if (b1 < reserve) {
            vm.prank(alice);
            vm.expectRevert(abi.encodeWithSelector(AuctionUpgradeable.BidTooLow.selector, 0));
            auction.placeBidToken(auctionId, "cid-a", b1);
            return;
        }

        vm.prank(alice);
        auction.placeBidToken(auctionId, "cid-a", b1);

        if (b2 <= b1) {
            vm.prank(bob);
            vm.expectRevert(abi.encodeWithSelector(AuctionUpgradeable.BidTooLow.selector, b1));
            auction.placeBidToken(auctionId, "cid-b", b2);
        } else {
            vm.prank(bob);
            auction.placeBidToken(auctionId, "cid-b", b2);
            assertEq(auction.getPendingReturns(auctionId, alice), b1);
            (,,,,, , uint256 highestBid,,) = auction.getAuction(auctionId);
            assertEq(highestBid, b2);
        }
    }*/
}

