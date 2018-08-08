pragma solidity ^0.4.24;

import "./libraries/RegistryLib.sol";

contract myRegistry {
    using SafeMath for uint;

    event skillRegistration(string indexed skillID, address indexed owner);
    event skillAccepted(string indexed skillID, address indexed owner);
    event skillUnregistered(string indexed skillID, address indexed owner);

    // General storage for Registry
    Registry.RegistryStorage public myRegistryStorage;

    // Constructor (fired once upon creation). Refactor for 0.4.24
    constructor() public {
        // Initially registry is not active
        myRegistryStorage.registryIsActive = false;

        myRegistryStorage.testNetworkAddress = 0x0000000000000000000000000000000000000000;
        myRegistryStorage.testTokenAddress = 0x0000000000000000000000000000000000000000;
    }

    function initialize(string _name, uint256 _stakePerRegistration, uint256 _stakePerArbiter, uint256 _stakePerValidator, address _owner) public onlyTestNetwork returns (bool success){
        require(Registry.initialize(myRegistryStorage, _name, _stakePerRegistration, _stakePerArbiter, _stakePerValidator, _owner));
        return true;
    }

    function closeRegistry() public onlyWeeveNetwork returns (bool success) {
        require(myRegistryStorage.activeskills == 0);
        myRegistryStorage.registryIsActive = false;
        return true;
    }

    function deactivateRegisty() public onlyWeeveNetwork returns (bool success) {
        myRegistryStorage.registryIsActive = false;
        return true;
    }

    // Request access to registry
    function requestRegistration(string _skillName, string _skillID, bytes32[] _skillMeta) public registryIsActive skillIDNotUsed(_skillID) hasEnoughTokensAllowed(msg.sender, myRegistryStorage.tokenStakePerRegistration) {
        require(testRegistry.requestRegistration(myRegistryStorage, _skillName, _skillID, _skillMeta, msg.sender));
        emit skillRegistration(_skillID, msg.sender);
        if(myRegistryStorage.skills[_skillID].stakedTokens > 0) {
            emit skillAccepted(_skillID, msg.sender);
        }
    }

    // Simulate approval [oraclize]
    function approveRegistrationRequest(string _skillID) public registryIsActive isValidator(msg.sender) skillExists(_skillID) hasEnoughTokensAllowed(myRegistryStorage.skills[_skillID].skillOwner, myRegistryStorage.tokenStakePerRegistration) {
        require(testRegistry.approveRegistrationRequest(myRegistryStorage, _skillID));
        emit skillAccepted(_skillID, myRegistryStorage.skills[_skillID].skillOwner);
    }

    // Unregistering skill
    function unregister(string _skillID) public isOwnerOfskill(_skillID) skillExists(_skillID) {
        require(testRegistry.unregister(myRegistryStorage, msg.sender, _skillID));
        emit skillUnregistered(_skillID, msg.sender);
    }

    // In case of programming errors or other bugs the owner is able to refund staked tokens from a registered skill to its owner
    // This will be removed once the contract is proven to work correctly
    function emergencyRefundRegistry(address _address) public onlyRegistryOwner {
        require(myRegistryStorage.totalStakedTokens[_address] > 0);
        myRegistryStorage.token.transfer(_address, myRegistryStorage.totalStakedTokens[_address]);
    }

    // Returns the total staked tokens of an address
    function getTotalStakeOfAddress(address _address) public view returns (uint256 totalStake) {
        require(_address == msg.sender || msg.sender == myRegistryStorage.registryOwner);
        return myRegistryStorage.totalStakedTokens[_address];
    }

    // Returns the basic information of a skill by its ID
    function getskillByID(string _skillID) public view skillExists(_skillID) returns (string skillName, string skillID, bytes32 hashOfskillData, address owner, uint256 stakedTokens, string registyState) {
        return (myRegistryStorage.skills[_skillID].skillName, myRegistryStorage.skills[_skillID].skillID, myRegistryStorage.skills[_skillID].hashOfskillData, myRegistryStorage.skills[_skillID].skillOwner, myRegistryStorage.skills[_skillID].stakedTokens, myRegistryStorage.skills[_skillID].state);
    }

    // Returns the first part of the metainformation of a skill by its ID
    function getskillMetainformation1ByID(string _skillID) public view skillExists(_skillID) returns (string sensors, string dataType, string manufacturer, string identifier, string description, string product) {
        return (myRegistryStorage.skills[_skillID].metainformation.sensors, myRegistryStorage.skills[_skillID].metainformation.dataType, myRegistryStorage.skills[_skillID].metainformation.manufacturer, myRegistryStorage.skills[_skillID].metainformation.identifier, myRegistryStorage.skills[_skillID].metainformation.description, myRegistryStorage.skills[_skillID].metainformation.product);
    }

    // Returns the basic information of a skill through the list of skills for an account
    function getskillIDFromUserArray(address _address, uint256 _skillPositionInArray) public view returns (string skillID) {
        return myRegistryStorage.skillsOfUser[_address][_skillPositionInArray];
    }

    // Returns amount of skills that an address has in this registry
    function getskillCountOfUser(address _address) public view returns (uint256 numberOfskills) {
        return myRegistryStorage.skillsOfUser[_address].length;
    }

    // Sets the amount of tokens to be staked for a registry
    function setStakePerRegistration(uint256 _numberOfTokens) public onlyRegistryOwner {
        myRegistryStorage.tokenStakePerRegistration = _numberOfTokens;
    }

    function addValidator(address _address) public registryIsActive onlyRegistryOwner {
        myRegistryStorage.validators[_address].validatorAddress = _address;
    }

    function removeValidator(address _address) public registryIsActive onlyRegistryOwner {
        delete myRegistryStorage.validators[_address];
    }

    function addArbiter(address _address) public registryIsActive onlyRegistryOwner {
        myRegistryStorage.arbiters[_address].arbiterAddress = _address;
    }

    function removeArbiter(address _address) public registryIsActive onlyRegistryOwner {
        delete myRegistryStorage.arbiters[_address];
    }

    function checkValidatorStatus(address _address) public view returns (bool status) {
        return myRegistryStorage.validators[_address].validatorAddress == _address;
    }

    function checkArbiterStatus(address _address) public view returns (bool status) {
        return myRegistryStorage.arbiters[_address].arbiterAddress == _address;
    }

    modifier onlyRegistryOwner {
        require(msg.sender == myRegistryStorage.registryOwner);
        _;
    }

    modifier onlyTestNetwork {
        require(msg.sender == myRegistryStorage.testNetworkAddress);
        _;
    }

    modifier hasEnoughTokensAllowed(address _address, uint256 _numberOfTokens) {
        require(myRegistryStorage.token.allowance(_address, address(this)) >= _numberOfTokens);
        _;
    }

    modifier isOwnerOfskill(string _skillID) {
        require(myRegistryStorage.skills[_skillID].skillOwner == msg.sender);
        _;
    }

    modifier isValidator(address _address) {
        require(myRegistryStorage.validators[_address].validatorAddress == _address);
        _;
    }

    modifier isArbiter(address _address) {
        require(myRegistryStorage.arbiters[_address].arbiterAddress == _address);
        _;
    }

    modifier skillExists(string _skillID) {
        require(bytes(myRegistryStorage.skills[_skillID].skillID).length > 0);
        _;
    }

    modifier skillIDNotUsed(string _skillID) {
        require(bytes(myRegistryStorage.skills[_skillID].skillID).length == 0);
        _;
    }

    modifier registryIsActive() {
        require(myRegistryStorage.registryIsActive);
        _;
    }
}
