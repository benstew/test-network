pragma solidity ^0.4.24;

import "./libraries/MarketplaceLib.sol";

contract myMarketplace {
    using SafeMath for uint;

    // Storage for the marketplace
    Marketplace.MarketplaceStorage public myMarketplaceStorage;

    address public networkAddress = 0x0000000000000000000000000000000000000000;
    address public tokenAddress = 0x0000000000000000000000000000000000000000;

    string public marketplaceName;

    // Constructor (fired once upon creation). Pending refactor
    constructor() public {
        // Initially the marketplace is not active
        myMarketplaceStorage.marketplaceIsActive = false;
    }

    function initialize(string _name, uint256 _commission, address _owner) public onlyNetwork returns (bool success){
        // Setting the name
        marketplaceName = _name;

        // Setting the owner
        require(_owner != address(0));
        myMarketplaceStorage.marketplaceOwner = _owner;

        // Number of active tasks
        myMarketplaceStorage.currentTasks = 0;

        // Activation of marketplace
        myMarketplaceStorage.marketplaceIsActive = true;

        // Setting a commission percentage
        require(_commission >= 0 && _commission < 100);
        myMarketplaceStorage.commission = _commission;

        // Initializing the the balance of the currently collected commission
        myMarketplaceStorage.commissionBalance = 0;

        // Activation of marketplace
        myMarketplaceStorage.marketplaceIsActive = true;

        // Setting the address of token
        myMarketplaceStorage.token = ERC20(tokenAddress);

        return true;
    }

    function closeMarketplace() public onlyNetwork returns (bool success) {
        require(myMarketplaceStorage.currentTasks == 0);
        myMarketplaceStorage.marketplaceIsActive = false;
        return true;
    }

    function deactivateMarketplace() public onlyNetwork returns (bool success) {
        myMarketplaceStorage.marketplaceIsActive = false;
        return true;
    }

    // Posting a new task offer
    function sell(string _taskID, uint256 _price, uint256 _amount) public marketplaceIsActive {
        require(Marketplace.sell(myMarketplaceStorage, _taskID, _price, _amount));
    }

    // Accepting a task offer
    function buy(string _taskID) public marketplaceIsActive {
        require(Marketplace.buy(myMarketplaceStorage, _taskID));
    }

    // Withdrawing the acrued commission
    function withdrawCommission(address _recipientAddress, uint256 _amountOfTokens) public marketplaceIsActive onlyMarketplaceOwner {
        // Withdrawal validation
        require(_amountOfTokens <= myMarketplaceStorage.commissionBalance);

        // Transfering tokens
        require(myMarketplaceStorage.token.transfer(_recipientAddress, _amountOfTokens));

        // Updating commission balance
        myMarketplaceStorage.commissionBalance = myMarketplaceStorage.commissionBalance.sub(_amountOfTokens);
    }

    // Returns the task info
    function getTask(string _taskID) public view returns (string taskID, address seller, uint256 price, uint256 amount, bool paid) {
        return(myMarketplaceStorage.tasks[_taskID].taskID, myMarketplaceStorage.tasks[_taskID].seller, myMarketplaceStorage.tasks[_taskID].price, myMarketplaceStorage.tasks[_taskID].amount, myMarketplaceStorage.tasks[_taskID].paid);
    }

    // Returns amount of skills for an address
    function getTotalTaskCount() public view returns (uint256 numberOfCurrentTasks) {
        return myMarketplaceStorage.currentTasks;
    }

    // Changeing the commission (as owner)
    function changeCommission(uint256 _commission) public marketplaceIsActive onlyMarketplaceOwner {
        require(_commission >= 0 && _commission < 100);
        myMarketplaceStorage.commission = _commission;
    }

    function addValidator(address _address) public marketplaceIsActive onlyMarketplaceOwner {
        myMarketplaceStorage.validators[_address].validatorAddress = _address;
    }

    function removeValidator(address _address) public marketplaceIsActive onlyMarketplaceOwner {
        delete myMarketplaceStorage.validators[_address];
    }

    function addArbiter(address _address) public marketplaceIsActive onlyMarketplaceOwner {
        myMarketplaceStorage.arbiters[_address].arbiterAddress = _address;
    }

    function removeArbiter(address _address) public marketplaceIsActive onlyMarketplaceOwner {
        delete myMarketplaceStorage.arbiters[_address];
    }

    function checkValidatorStatus(address _address) public view returns (bool status) {
        if(myMarketplaceStorage.validators[_address].validatorAddress == _address) {
            return true;
        } else {
            return false;
        }
    }

    function checkArbiterStatus(address _address) public view returns (bool status) {
        if(myMarketplaceStorage.arbiters[_address].arbiterAddress == _address) {
            return true;
        } else {
            return false;
        }
    }

    // Modifiers
    modifier onlyNetwork {
        require(msg.sender == networkAddress);
        _;
    }

    modifier onlyMarketplaceOwner {
        require(msg.sender == myMarketplaceStorage.marketplaceOwner);
        _;
    }

    modifier isValidator(address _address) {
        require(myMarketplaceStorage.validators[_address].validatorAddress == _address);
        _;
    }

    modifier isArbiter(address _address) {
        require(myMarketplaceStorage.arbiters[_address].arbiterAddress == _address);
        _;
    }

    modifier marketplaceIsActive() {
        require(myMarketplaceStorage.marketplaceIsActive);
        _;
    }
}
