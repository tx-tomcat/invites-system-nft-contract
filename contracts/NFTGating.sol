// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract NFTGating is ReentrancyGuard, Pausable, AccessControl {

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");
    
    IERC721 public mocaNFT;
    
    // Simple counters for analytics
    uint256 private _totalStakes;
    uint256 private _totalRegistrations;
    
    // Configuration
    uint256 public minimumStakingPeriod = 1 weeks;
    uint256 public maxDelegationsPerWallet = 3;
    uint256 public cooldownPeriod = 1 days;
    
    // Staking details
    struct Stake {
        uint256 timestamp;
        bool isStaked;
        uint256 lastActionTimestamp;
    }
    
    // Extended delegation tracking
    struct DelegationInfo {
        address delegate;
        uint256 timestamp;
        bool isActive;
    }
    
    // Mapping from token ID to stake details
    mapping(uint256 => Stake) public stakes;
    
    // Mapping from wallet to registered email hash
    mapping(address => bytes32) public registeredEmails;
    
    // Enhanced delegation tracking
    mapping(address => DelegationInfo[]) public delegationHistory;
    mapping(address => uint256) public delegationCount;
    mapping(address => uint256) public lastDelegationTimestamp;
    
    // Blacklist for abuse prevention
    mapping(address => bool) public blacklistedAddresses;
    
    // Events
    event NFTStaked(address indexed owner, uint256 tokenId);
    event NFTUnstaked(address indexed owner, uint256 tokenId);
    event EmailRegistered(address indexed wallet, bytes32 emailHash);
    event DelegationSet(address indexed delegator, address indexed delegate);
    event AddressBlacklisted(address indexed wallet, address indexed by);
    event ConfigurationUpdated(string parameter, uint256 value);
    event EmergencyActionTaken(string action, address indexed by);
    
    // Modifiers
    modifier notBlacklisted(address _address) {
        require(!blacklistedAddresses[_address], "Address is blacklisted");
        _;
    }
    
    modifier withinDelegationLimit(address _address) {
        require(delegationCount[_address] < maxDelegationsPerWallet, "Delegation limit reached");
        _;
    }
    
    modifier cooldownCompleted(address _address) {
        require(
            block.timestamp >= lastDelegationTimestamp[_address] + cooldownPeriod,
            "Cooldown period not completed"
        );
        _;
    }
    
    constructor(address _mocaNFTAddress) {
        mocaNFT = IERC721(_mocaNFTAddress);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        
        _totalStakes = 0;
        _totalRegistrations = 0;
    }
    
    // Admin functions
    function setMinimumStakingPeriod(uint256 _period) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        require(_period > 0, "Invalid period");
        minimumStakingPeriod = _period;
        emit ConfigurationUpdated("minimumStakingPeriod", _period);
    }
    
    function setMaxDelegationsPerWallet(uint256 _max) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        require(_max > 0, "Invalid max delegations");
        maxDelegationsPerWallet = _max;
        emit ConfigurationUpdated("maxDelegationsPerWallet", _max);
    }
    
    function setCooldownPeriod(uint256 _period) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        cooldownPeriod = _period;
        emit ConfigurationUpdated("cooldownPeriod", _period);
    }
    
    function blacklistAddress(address _address) 
        external 
        onlyRole(MODERATOR_ROLE) 
    {
        blacklistedAddresses[_address] = true;
        emit AddressBlacklisted(_address, msg.sender);
    }
    
    function emergencyPause() 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        _pause();
        emit EmergencyActionTaken("pause", msg.sender);
    }
    
    function emergencyUnpause() 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        _unpause();
        emit EmergencyActionTaken("unpause", msg.sender);
    }
    
    // Enhanced staking function
    function stakeNFT(uint256 tokenId) 
        external 
        nonReentrant 
        whenNotPaused 
        notBlacklisted(msg.sender) 
    {
        require(mocaNFT.ownerOf(tokenId) == msg.sender, "Not token owner");
        require(!stakes[tokenId].isStaked, "Already staked");
        require(
            block.timestamp >= stakes[tokenId].lastActionTimestamp + cooldownPeriod,
            "Cooldown period not completed"
        );
        
        stakes[tokenId] = Stake({
            timestamp: block.timestamp,
            isStaked: true,
            lastActionTimestamp: block.timestamp
        });
        
        _totalStakes++;
        emit NFTStaked(msg.sender, tokenId);
    }
    
    // Enhanced delegation function
    function setDelegation(address delegate) 
        external 
        nonReentrant 
        whenNotPaused 
        notBlacklisted(msg.sender) 
        notBlacklisted(delegate) 
        withinDelegationLimit(msg.sender)
        cooldownCompleted(msg.sender)
    {
        require(delegate != address(0), "Invalid delegate address");
        require(delegate != msg.sender, "Cannot delegate to self");
        
        // Update delegation tracking
        delegationHistory[msg.sender].push(DelegationInfo({
            delegate: delegate,
            timestamp: block.timestamp,
            isActive: true
        }));
        
        delegationCount[msg.sender]++;
        lastDelegationTimestamp[msg.sender] = block.timestamp;
        
        emit DelegationSet(msg.sender, delegate);
    }
    
    // Enhanced email registration
    function registerEmail(bytes32 emailHash, uint256 tokenId) 
        external 
        nonReentrant 
        whenNotPaused 
        notBlacklisted(msg.sender) 
    {
        require(emailHash != bytes32(0), "Invalid email hash");
        
        address effectiveOwner = msg.sender;
        
        // Check delegation status
        if (hasDelegation(msg.sender)) {
            effectiveOwner = getActiveDelegate(msg.sender);
            require(
                !blacklistedAddresses[effectiveOwner],
                "Delegate is blacklisted"
            );
        }
        
        // Verify NFT ownership and staking requirement
        require(
            mocaNFT.ownerOf(tokenId) == effectiveOwner,
            "Not token owner or delegate"
        );
        require(meetsStakingRequirement(tokenId), "Staking requirement not met");
        
        // Verify email hasn't been registered
        require(
            registeredEmails[effectiveOwner] == bytes32(0),
            "Email already registered"
        );
        
        registeredEmails[effectiveOwner] = emailHash;
        _totalRegistrations++;
        
        emit EmailRegistered(effectiveOwner, emailHash);
    }
    
    // Helper functions
    function meetsStakingRequirement(uint256 tokenId) 
        public 
        view 
        returns (bool) 
    {
        Stake memory stake = stakes[tokenId];
        return stake.isStaked && 
               (block.timestamp - stake.timestamp >= minimumStakingPeriod);
    }
    
    function hasDelegation(address _address) 
        public 
        view 
        returns (bool) 
    {
        if (delegationHistory[_address].length == 0) return false;
        return delegationHistory[_address][delegationHistory[_address].length - 1].isActive;
    }
    
    function getActiveDelegate(address _address) 
        public 
        view 
        returns (address) 
    {
        if (!hasDelegation(_address)) return address(0);
        return delegationHistory[_address][delegationHistory[_address].length - 1].delegate;
    }
    
    // Analytics functions
    function getTotalStakes() external view returns (uint256) {
        return _totalStakes;
    }
    
    function getTotalRegistrations() external view returns (uint256) {
        return _totalRegistrations;
    }
}
