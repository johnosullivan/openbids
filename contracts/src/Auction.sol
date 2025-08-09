// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title Auction
 * @dev Manages multiple time-boxed English auctions. Each bid includes an IPFS CID payload.
 * Uses the withdrawal pattern per-auction to safely refund outbid bidders.
 */
contract Auction {
    // Errors
    error AuctionNotStarted();
    error AuctionEnded();
    error BidTooLow(uint256 currentHighestBid);
    error NothingToWithdraw();
    error WithdrawFailed();
    error AlreadyFinalized();
    error AuctionStillActive(uint64 endTime, uint256 nowTs);
    error AuctionDoesNotExist();

    // Events
    event AuctionCreated(
        uint256 indexed auctionId,
        address indexed creator,
        address indexed beneficiary,
        uint64 startTime,
        uint64 endTime,
        uint256 reservePrice
    );
    event BidPlaced(
        uint256 indexed auctionId,
        address indexed bidder,
        uint256 amount,
        string ipfsCid,
        uint64 timestamp
    );
    event Withdrawal(uint256 indexed auctionId, address indexed bidder, uint256 amount);
    event AuctionFinalized(
        uint256 indexed auctionId,
        address indexed winner,
        uint256 amount,
        string ipfsCid,
        address indexed beneficiary
    );

    struct AuctionData {
        address creator;
        address payable beneficiary;
        uint64 startTime; // unix seconds
        uint64 endTime;   // unix seconds
        uint256 reservePrice;
        address highestBidder;
        uint256 highestBid;
        string highestBidIpfsCid;
        bool finalized;
    }

    // Storage
    uint256 public nextAuctionId;
    mapping(uint256 => AuctionData) public auctions; // auctionId => auction data
    mapping(uint256 => mapping(address => uint256)) public pendingReturns; // auctionId => bidder => amount

    /**
     * @notice Create a new auction
     * @param _beneficiary Address that will receive the winning funds
     * @param _startTime Auction start time (unix seconds). Must be >= current block timestamp
     * @param _endTime Auction end time (unix seconds). Must be > _startTime
     * @param _reservePrice Minimum price required for the auction to be valid
     * @return auctionId The created auction id
     */
    function createAuction(
        address payable _beneficiary,
        uint64 _startTime,
        uint64 _endTime,
        uint256 _reservePrice
    ) external returns (uint256 auctionId) {
        require(_beneficiary != address(0), "Invalid beneficiary");
        require(_endTime > _startTime, "Invalid time window");
        require(_startTime >= block.timestamp, "Start time in past");

        auctionId = nextAuctionId;
        nextAuctionId = auctionId + 1;

        AuctionData storage a = auctions[auctionId];
        a.creator = msg.sender;
        a.beneficiary = _beneficiary;
        a.startTime = _startTime;
        a.endTime = _endTime;
        a.reservePrice = _reservePrice;

        emit AuctionCreated(auctionId, msg.sender, _beneficiary, _startTime, _endTime, _reservePrice);
    }

    /**
     * @notice Place a bid on a specific auction and attach an IPFS CID as the bid payload.
     * @dev The highest bid must strictly exceed the current highest bid.
     * Funds from the previous highest bidder become withdrawable per-auction.
     * @param auctionId The id of the auction to bid on
     * @param ipfsCid IPFS content identifier string (e.g., CIDv0 base58 or CIDv1 base32)
     */
    function placeBid(uint256 auctionId, string calldata ipfsCid) external payable {
        AuctionData storage a = auctions[auctionId];
        if (a.endTime == 0) revert AuctionDoesNotExist();

        uint256 nowTs = block.timestamp;
        if (nowTs < a.startTime) revert AuctionNotStarted();
        if (nowTs >= a.endTime) revert AuctionEnded();

        uint256 newBid = msg.value;
        // Enforce reserve price for the first valid bid
        uint256 minRequired = a.highestBid == 0 ? a.reservePrice : (a.highestBid + 1);
        if (newBid <= a.highestBid || newBid < minRequired) {
            revert BidTooLow(a.highestBid);
        }

        // Refund previous highest bidder via withdrawal pattern
        if (a.highestBidder != address(0)) {
            pendingReturns[auctionId][a.highestBidder] += a.highestBid;
        }

        a.highestBidder = msg.sender;
        a.highestBid = newBid;
        a.highestBidIpfsCid = ipfsCid;

        emit BidPlaced(auctionId, msg.sender, newBid, ipfsCid, uint64(nowTs));
    }

    /**
     * @notice Withdraw refundable funds for a specific auction if you have been outbid.
     * @param auctionId The id of the auction
     */
    function withdraw(uint256 auctionId) external {
        uint256 amount = pendingReturns[auctionId][msg.sender];
        if (amount == 0) revert NothingToWithdraw();

        // Effects before interaction
        pendingReturns[auctionId][msg.sender] = 0;

        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        if (!ok) {
            // Restore state on failure
            pendingReturns[auctionId][msg.sender] = amount;
            revert WithdrawFailed();
        }
        emit Withdrawal(auctionId, msg.sender, amount);
    }

    /**
     * @notice Finalize an auction after it ends. Transfers the highest bid to the beneficiary if reserve is met.
     * Can be called by anyone.
     * @param auctionId The id of the auction to finalize
     */
    function finalize(uint256 auctionId) external {
        AuctionData storage a = auctions[auctionId];
        if (a.endTime == 0) revert AuctionDoesNotExist();
        if (a.finalized) revert AlreadyFinalized();

        uint256 nowTs = block.timestamp;
        if (nowTs < a.endTime) revert AuctionStillActive(a.endTime, nowTs);

        a.finalized = true;

        // Only transfer if the reserve was met and a winning bid exists
        if (a.highestBidder != address(0) && a.highestBid >= a.reservePrice) {
            (bool ok, ) = a.beneficiary.call{value: a.highestBid}("");
            require(ok, "Payout failed");
        }

        emit AuctionFinalized(auctionId, a.highestBidder, a.highestBid, a.highestBidIpfsCid, a.beneficiary);
    }

    /**
     * @notice Check whether a given auction is currently active
     * @param auctionId The id of the auction
     * @return active Whether the auction is active (has started, not yet ended, and not finalized)
     */
    function isActive(uint256 auctionId) external view returns (bool active) {
        AuctionData storage a = auctions[auctionId];
        if (a.endTime == 0) return false;
        return block.timestamp >= a.startTime && block.timestamp < a.endTime && !a.finalized;
    }

    /**
     * @notice Get full details for an auction
     */
    function getAuction(uint256 auctionId)
        external
        view
        returns (
            address creator,
            address beneficiary,
            uint64 startTime,
            uint64 endTime,
            uint256 reservePrice,
            address highestBidder,
            uint256 highestBid,
            string memory highestBidIpfsCid,
            bool finalized
        )
    {
        AuctionData storage a = auctions[auctionId];
        if (a.endTime == 0) revert AuctionDoesNotExist();
        return (
            a.creator,
            a.beneficiary,
            a.startTime,
            a.endTime,
            a.reservePrice,
            a.highestBidder,
            a.highestBid,
            a.highestBidIpfsCid,
            a.finalized
        );
    }

    /**
     * @notice View how much a bidder can withdraw for an auction
     */
    function getPendingReturns(uint256 auctionId, address bidder) external view returns (uint256) {
        return pendingReturns[auctionId][bidder];
    }
}

