// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title BountyHunter
 * @dev A decentralized bounty hunting platform where users can post bounties and hunters can claim rewards
 */
contract BountyHunter {
    
    struct Bounty {
        uint256 id;
        address creator;
        string title;
        string description;
        uint256 reward;
        bool isCompleted;
        bool exists;
        address hunter;
        uint256 createdAt;
    }
    
    mapping(uint256 => Bounty) public bounties;
    mapping(address => uint256[]) public userBounties;
    mapping(address => uint256[]) public hunterCompletedBounties;
    
    uint256 public nextBountyId = 1;
    uint256 public totalBounties = 0;
    uint256 public totalRewardsDistributed = 0;
    
    event BountyCreated(
        uint256 indexed bountyId,
        address indexed creator,
        string title,
        uint256 reward
    );
    
    event BountyClaimed(
        uint256 indexed bountyId,
        address indexed hunter,
        uint256 reward
    );
    
    event BountyCompleted(
        uint256 indexed bountyId,
        address indexed hunter,
        uint256 reward
    );
    
    modifier bountyExists(uint256 _bountyId) {
        require(bounties[_bountyId].exists, "Bounty does not exist");
        _;
    }
    
    modifier onlyBountyCreator(uint256 _bountyId) {
        require(bounties[_bountyId].creator == msg.sender, "Only bounty creator can perform this action");
        _;
    }
    
    modifier bountyNotCompleted(uint256 _bountyId) {
        require(!bounties[_bountyId].isCompleted, "Bounty already completed");
        _;
    }
    
    /**
     * @dev Create a new bounty with ETH reward
     * @param _title The title of the bounty
     * @param _description Detailed description of the bounty task
     */
    function createBounty(string memory _title, string memory _description) external payable {
        require(msg.value > 0, "Reward must be greater than 0");
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");
        
        uint256 bountyId = nextBountyId;
        
        bounties[bountyId] = Bounty({
            id: bountyId,
            creator: msg.sender,
            title: _title,
            description: _description,
            reward: msg.value,
            isCompleted: false,
            exists: true,
            hunter: address(0),
            createdAt: block.timestamp
        });
        
        userBounties[msg.sender].push(bountyId);
        totalBounties++;
        nextBountyId++;
        
        emit BountyCreated(bountyId, msg.sender, _title, msg.value);
    }
    
    /**
     * @dev Get bounty details by ID
     * @param _bountyId The ID of the bounty to retrieve
     * @return Bounty struct with all details
     */
    function getBounty(uint256 _bountyId) external view bountyExists(_bountyId) returns (Bounty memory) {
        return bounties[_bountyId];
    }
    
    /**
     * @dev Claim a bounty as a hunter (first come, first served)
     * @param _bountyId The ID of the bounty to claim
     */
    function claimBounty(uint256 _bountyId) external bountyExists(_bountyId) bountyNotCompleted(_bountyId) {
        require(bounties[_bountyId].hunter == address(0), "Bounty already claimed");
        require(bounties[_bountyId].creator != msg.sender, "Cannot claim your own bounty");
        
        bounties[_bountyId].hunter = msg.sender;
        
        emit BountyClaimed(_bountyId, msg.sender, bounties[_bountyId].reward);
    }
    
    /**
     * @dev Complete bounty and release reward to hunter (only bounty creator)
     * @param _bountyId The ID of the bounty to complete
     */
    function completeBounty(uint256 _bountyId) external 
        bountyExists(_bountyId) 
        onlyBountyCreator(_bountyId) 
        bountyNotCompleted(_bountyId) 
    {
        require(bounties[_bountyId].hunter != address(0), "Bounty not claimed yet");
        
        address hunter = bounties[_bountyId].hunter;
        uint256 reward = bounties[_bountyId].reward;
        
        bounties[_bountyId].isCompleted = true;
        hunterCompletedBounties[hunter].push(_bountyId);
        totalRewardsDistributed += reward;
        
        // Transfer reward to hunter
        payable(hunter).transfer(reward);
        
        emit BountyCompleted(_bountyId, hunter, reward);
    }
    
    /**
     * @dev Cancel bounty and refund creator (only if not claimed)
     * @param _bountyId The ID of the bounty to cancel
     */
    function cancelBounty(uint256 _bountyId) external 
        bountyExists(_bountyId) 
        onlyBountyCreator(_bountyId) 
        bountyNotCompleted(_bountyId) 
    {
        require(bounties[_bountyId].hunter == address(0), "Cannot cancel claimed bounty");
        
        uint256 refundAmount = bounties[_bountyId].reward;
        bounties[_bountyId].reward = 0;
        bounties[_bountyId].exists = false;
        totalBounties--;
        
        // Refund to creator
        payable(msg.sender).transfer(refundAmount);
    }
    
    /**
     * @dev Get all bounty IDs created by a user
     * @param _user The address of the user
     * @return Array of bounty IDs
     */
    function getUserBounties(address _user) external view returns (uint256[] memory) {
        return userBounties[_user];
    }
    
    // Additional view functions for better UX
    function getContractStats() external view returns (uint256, uint256, uint256) {
        return (totalBounties, totalRewardsDistributed, address(this).balance);
    }
    
    function getHunterCompletedBounties(address _hunter) external view returns (uint256[] memory) {
        return hunterCompletedBounties[_hunter];
    }
}
