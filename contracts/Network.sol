pragma solidity ^0.4.24;

import "./libraries/SafeMath.sol";
import "./libraries/Owned.sol";

// Basic ERC20 Interface
interface ERC20 {
    function totalSupply() external returns (uint);
    function balanceOf(address tokenOwner) external returns (uint256 balance);
    function allowance(address tokenOwner, address spender) external returns (uint256 remaining);
    function transfer(address to, uint256 tokens) external returns (bool success);
    function approve(address spender, uint256 tokens) external returns (bool success);
    function transferFrom(address from, address to, uint256 tokens) external returns (bool success);
}

// Interface for registries
interface testRegistry {
    function initialize(string _name, uint256 _stakePerRegistration, uint256 _stakePerArbiter, uint256 _stakePerValidator, address _owner) external returns (bool success);
    function deactivateRegisty() external returns (bool success);
    function closeRegistry() external returns (bool success);
    function getTotalskillCount() external returns (uint256 numberOfskills);
}

// Interface for marketplaces
interface testMarketplace {
    function initialize(string _name, uint256 _commission, address _owner) external returns (bool success);
    function deactivateMarketplace() external returns (bool success);
    function closeMarketplace() external returns (bool success);
    function getTotalTradeCount() external returns (uint256 numberOfCurrentTrades);
}

contract Network is Owned {
    using SafeMath for uint;

    bytes32 public testRegistryHash;
    bytes32 public testMarketplaceHash;

    mapping(address => uint256[]) userRegistries;
    mapping(address => uint256[]) userMarketplaces;
    mapping(address => bool) hasWithdrawnTestToken;

    struct Registry {
        uint256 id;
        string name;
        address owner;
        address registryAddress;
        uint256 stakedTokens;
        bool active;
        bool challenged;
    }

    struct Marketplace {
        uint256 id;
        string name;
        address owner;
        address marketplaceAddress;
        uint256 stakedTokens;
        bool active;
        bool challenged;
    }

    // Array of all registries
    Registry[] public allRegistries;

    // Array of all registries
    Marketplace[] public allMarketplaces;

    // Our ERC20 token
    ERC20 public token;

    // Address to number of staked tokens per user
    mapping (address => uint) totalStakedTokens;

    // Tokens that need to be staked for each registry (soon to be dynamic)
    uint256 tokensPerRegistryCreation;

    // Tokens that need to be staked for each registry (soon to be dynamic)
    uint256 tokensPerMarketplaceCreation;

    constructor(address _erc20Address) public {
        require(_erc20Address != address(0));

        // Setting the address of our WEEV token contract
        token = ERC20(_erc20Address);

        // placeholder
        testRegistryHash = 0x0000000000000000000000000000000000000000000000000000000000000000;

        // placeholder
        testMarketplaceHash = 0x0000000000000000000000000000000000000000000000000000000000000000;

        // Allocatied okens
        tokensPerRegistryCreation = 1000 * 10**18;

        // Tokens per Marketplace
        tokensPerMarketplaceCreation = 1000 * 10**18;
    }

    // Setting a new valid registry code
    function setNewRegistryHash(bytes _contractCode) public onlyOwner {
        testRegistryHash = keccak256(_contractCode);
    }

    // Setting a new valid marketplace
    function setNewMarketplaceHash(bytes _contractCode) public onlyOwner {
        testMarketplaceHash = keccak256(_contractCode);
    }

    // Setting a new stake for marketplace
    function setNewMarketplaceStake(uint256 _newStakeMarketplace) public onlyOwner {
        tokensPerMarketplaceCreation = _newStakeMarketplace;
    }

    // Setting a new stake for registry creatio
    function setNewRegistryStake(uint256 _newStakeRegistry) public onlyOwner {
        tokensPerRegistryCreation = _newStakeRegistry;
    }

    // Creating a new registry
    function createRegistry(string _name, uint256 _stakePerRegistration, uint256 _stakePerArbiter, uint256 _stakePerValidator, bytes _contractCode) public hasEnoughTokensAllowed(msg.sender, tokensPerRegistryCreation) returns (address newRegistryAddress) {

        // Allocating a new registry struct
        Registry memory newRegistry;
        newRegistry.id = allRegistries.length;
        newRegistry.name = _name;
        newRegistry.owner = msg.sender;

        // Staking
        newRegistry.stakedTokens = stakeTokens(msg.sender, tokensPerRegistryCreation);
        require(newRegistry.stakedTokens >= tokensPerRegistryCreation);

        totalStakedTokens[msg.sender] = totalStakedTokens[msg.sender].add(newRegistry.stakedTokens);

        // Deploying
        newRegistry.registryAddress = deployCode(_contractCode);
        require(newRegistry.registryAddress != address(0));

        // Activating
        testRegistry newTestRegistry = testRegistry(newRegistry.registryAddress);
        require(newTestRegistry.initialize(_name, _stakePerRegistration, _stakePerArbiter, _stakePerValidator, msg.sender));

        newRegistry.active = true;

        // Adding the registry to users registry array
        userRegistries[msg.sender].push(newRegistry.id);

        // Adding the registry to general registry array
        allRegistries.push(newRegistry);

        // Registration address
        return newRegistry.registryAddress;
    }

    // Creating a marketplace
    function createMarketplace(string _name, uint256 _commission, bytes _contractCode) public hasEnoughTokensAllowed(msg.sender, tokensPerMarketplaceCreation) returns (address newMarketplaceAddress) {

        // Allocating a new marketplace struct
        Marketplace memory newMarketplace;
        newMarketplace.id = allMarketplaces.length;
        newMarketplace.name = _name;
        newMarketplace.owner = msg.sender;

        // Staking
        newMarketplace.stakedTokens = stakeTokens(msg.sender, tokensPerMarketplaceCreation);
        require(newMarketplace.stakedTokens >= tokensPerMarketplaceCreation);

        totalStakedTokens[msg.sender] = totalStakedTokens[msg.sender].add(newMarketplace.stakedTokens);

        // Deploying
        newMarketplace.marketplaceAddress = deployCode(_contractCode);
        require(newMarketplace.marketplaceAddress != address(0));

        // Activating
        weeveMarketplace newTestMarketplace = testMarketplace(newMarketplace.marketplaceAddress);
        require(newTestMarketplace.initialize(_name, _commission, msg.sender));

        newMarketplace.active = true;

        // Adding the marketplace
        userMarketplaces[msg.sender].push(newMarketplace.id);

        // Adding the marketplace to the general marketplace array
        allMarketplaces.push(newMarketplace);

        // Returning the marketplaces address
        return newMarketplace.marketplaceAddress;
    }

    // Internal function to deploy bytecode to the blockchain
    function deployCode(bytes _contractCode) internal returns (address addr) {
        uint256 asmReturnValue;

        assembly {
            addr := create(0,add(_contractCode,0x20), mload(_contractCode))
            asmReturnValue := gt(extcodesize(addr),0)
        }
        require(asmReturnValue > 0);
    }

    // Closing a registry where no skills are active (only owner action)
    function closeRegistry(uint256 _id) public isOwnerOfRegistry(msg.sender, _id) {
        testRegistry theRegistry = testRegistry(allRegistries[_id].registryAddress);
        // Calling the closeRegistry
        require(theRegistry.closeRegistry());
         // Unstaking
        require(unstakeTokens(allRegistries[_id].owner, allRegistries[_id].stakedTokens));
        totalStakedTokens[msg.sender] = totalStakedTokens[msg.sender].sub(allRegistries[_id].stakedTokens);

        allRegistries[_id].stakedTokens = 0;
        allRegistries[_id].active = false;
    }

    // Closing a registry where no skills are active
    function closeMarketplace(uint256 _id) public isOwnerOfMarketplace(msg.sender, _id) {
        testMarketplace theMarketplace = testMarketplace(allMarketplaces[_id].marketplaceAddress);
        // Only if amount of active skills is 0
        require(theMarketplace.getTotalTradeCount() == 0);

        require(theMarketplace.closeMarketplace());
        // Unstaking
        require(unstakeTokens(allMarketplaces[_id].owner, allMarketplaces[_id].stakedTokens));
        totalStakedTokens[msg.sender] = totalStakedTokens[msg.sender].sub(allMarketplaces[_id].stakedTokens);
        allMarketplaces[_id].stakedTokens = 0;
        allMarketplaces[_id].active = false;
    }

    // Stake tokens
    function stakeTokens(address _address, uint256 _numberOfTokens) internal returns (uint256) {
        require(token.transferFrom(_address, address(this), _numberOfTokens));
        return _numberOfTokens;
    }

    // Unstake tokens
    function unstakeTokens(address _address, uint256 _numberOfTokens) internal returns (bool) {
        require(token.balanceOf(address(this)) >= _numberOfTokens);
        require(token.transfer(_address, _numberOfTokens));
        return true;
    }

    modifier hasEnoughTokensAllowed(address _address, uint256 _numberOfTokens) {
        require(token.allowance(_address, address(this)) >= _numberOfTokens);
        _;
    }

    modifier isOwnerOfRegistry(address _address, uint256 _id) {
        require(allRegistries[_id].owner == _address);
        _;
    }

    modifier isOwnerOfMarketplace(address _address, uint256 _id) {
        require(allMarketplaces[_id].owner == _address);
        _;
    }
}
