// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract TenderManagementSystem {
    address public manager;
    uint public tenderCount;

    enum TenderStatus { Open, Closed }

    struct Tender {
        uint id;
        string title;
        string description;
        uint deadline;
        uint minimumBudget;
        TenderStatus status;
        address winner;
    }

    struct Bid {
        address bidder;
        uint bidAmount;
        uint deadline;
    }

    mapping(uint => Tender) public tenders;
    mapping(uint => mapping(address => bool)) public hasBid;
    mapping(uint => Bid[]) public eligibleBidders;
    mapping(uint => Bid[]) public allBidders;

    event TenderIssued(uint id, string title, string description, uint deadline, uint minimumBudget);
    event BidPlaced(uint tenderId, address bidder, uint deadline, uint bidAmount);
    event TenderClosed(uint id, address winner);

    modifier onlyManager() {
        require(msg.sender == manager, "Only the manager can perform this action");
        _;
    }

    modifier tenderOpen(uint _tenderId) {
        require(tenders[_tenderId].status == TenderStatus.Open, "Tender is closed");
        _;
    }

    constructor() {
        manager = msg.sender;
    }

    function issueTender(string memory _title, string memory _description, uint _deadline, uint _minimumBudget) external onlyManager {
        tenderCount++;
        Tender storage newTender = tenders[tenderCount];
        newTender.id = tenderCount;
        newTender.title = _title;
        newTender.description = _description;
        newTender.deadline = _deadline;
        newTender.minimumBudget = _minimumBudget;
        newTender.status = TenderStatus.Open;

        emit TenderIssued(tenderCount, _title, _description, _deadline, _minimumBudget);
    }

    function placeBid(uint _tenderId, uint _deadline, uint _bidAmount) external tenderOpen(_tenderId) {
        require(!hasBid[_tenderId][msg.sender], "You have already placed a bid");

        emit BidPlaced(_tenderId, msg.sender, _deadline, _bidAmount);

        Bid memory bid = Bid({
            bidder: msg.sender,
            bidAmount: _bidAmount,
            deadline: _deadline
        });

        // Store the bid details in allBidders
        allBidders[_tenderId].push(bid);

        // Store the bid details in eligibleBidders only if the bid is eligible
        if (_bidAmount >= tenders[_tenderId].minimumBudget && _deadline >= tenders[_tenderId].deadline) {
            eligibleBidders[_tenderId].push(bid);
        }

        hasBid[_tenderId][msg.sender] = true;
    }

    function viewAllBidders(uint _tenderId) external view returns (Bid[] memory) {
        return allBidders[_tenderId];
    }

    function viewEligibleBidders(uint _tenderId) external view returns (Bid[] memory) {
        // require(tenders[_tenderId].status == TenderStatus.Open, "Tender is closed");
        return eligibleBidders[_tenderId];
    }

    function closeTender(uint _tenderId) external onlyManager tenderOpen(_tenderId) {
        Tender storage currentTender = tenders[_tenderId];
        currentTender.status = TenderStatus.Closed;

        // call determineWinner function
        currentTender.winner = determineWinner(_tenderId);

        emit TenderClosed(_tenderId, currentTender.winner);
    }

    function determineWinner(uint _tenderId) internal view returns (address) {
        require(tenders[_tenderId].status == TenderStatus.Closed, "Tender is not closed yet");

        Bid[] memory bids = eligibleBidders[_tenderId];
        require(bids.length > 0, "No eligible bidders");

        address winningBidder = address(0);
        uint winningBidAmount = type(uint).max;
        uint earliestDeadline = type(uint).max;

        // Iterate through eligible bidders
        for (uint i = 0; i < bids.length; i++) {
            Bid memory currentBid = bids[i];

            // Check if the current bidder has a lower bid amount or earlier deadline
            if (currentBid.bidAmount < winningBidAmount || (currentBid.bidAmount == winningBidAmount && currentBid.deadline < earliestDeadline)) {
                winningBidder = currentBid.bidder;
                winningBidAmount = currentBid.bidAmount;
                earliestDeadline = currentBid.deadline;
            }
        }

        return winningBidder;
    }
}

