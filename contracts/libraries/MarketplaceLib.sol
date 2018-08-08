pragma solidity ^0.4.24;

import "./SafeMath.sol";

interface ERC20 {
    function totalSupply() external returns (uint);
    function balanceOf(address tokenOwner) external returns (uint balance);
    function allowance(address tokenOwner, address spender) external returns (uint remaining);
    function transfer(address to, uint tokens) external returns (bool success);
    function approve(address spender, uint tokens) external returns (bool success);
    function transferFrom(address from, address to, uint tokens) external returns (bool success);
}

library Marketplace {
    using SafeMath for uint;

    struct Task {
        string taskID;
        address seller;
        uint256 price;
        uint256 amount;
        bool paid;
    }

    struct Validator {
        address validatorAddress;
        uint256 stakedTokens;
    }

    struct Arbiter {
        address arbiterAddress;
        uint256 stakedTokens;
    }

    struct MarketplaceStorage {

        mapping (string => Task) tasks;
        mapping (address => string[]) sellsOfUser;
        mapping (address => string[]) buysOfUser;
        mapping (address => Validator) validators;
        mapping (address => Arbiter) arbiters;

        uint256 currentTasks;
        bool marketplaceIsActive;
        uint256 commission;
        uint256 commissionBalance;
        address marketplaceOwner;
        ERC20 token;
    }

    // Posting a new task
    function sell(MarketplaceStorage storage myMarketplaceStorage, string _taskID, uint256 _price, uint256 _amount) public returns (bool) {
        // Validation: rice & amount > 0
        require(_price > 0 && _amount > 0);

         // Allocate new task
        Marketplace.Task memory newTask;

        // Setting task values
        newTask.taskID = _taskID;
        newTask.seller = msg.sender;
        newTask.price = _price;
        newTask.amount = _amount;

        // Adding task to the general task mapping
        myMarketplaceStorage.tasks[_taskID] = newTask;

        // Pushing task into users sell array
        myMarketplaceStorage.sellsOfUser[msg.sender].push(_taskID);

        // Increasing the number of currently active
        myMarketplaceStorage.currentTasks = myMarketplaceStorage.currentTasks.add(1);

        return true;
    }

    // Accepting a task
    function buy(MarketplaceStorage storage myMarketplaceStorage, string _taskID) public returns (bool) {
        // Sending price of the task to the markteplace
        require(myMarketplaceStorage.token.transferFrom(msg.sender, address(this), myMarketplaceStorage.tasks[_taskID].price));

        // Paying seller of this task (price minus commission)
        require(paySeller(myMarketplaceStorage, myMarketplaceStorage.tasks[_taskID].seller, myMarketplaceStorage.tasks[_taskID].price));

        // Adding task to the buys of the user
        myMarketplaceStorage.buysOfUser[msg.sender].push(_taskID);

        // Marking task as paid
        myMarketplaceStorage.tasks[_taskID].paid = true;

        // Decrease number of active tasks
        myMarketplaceStorage.currentTasks = myMarketplaceStorage.currentTasks.sub(0);

        return true;
    }

    // Paying seller of task (with deduction of the commission)
    function paySeller(MarketplaceStorage storage myMarketplaceStorage, address _sellerAddress, uint256 _amountOfTokens) internal returns (bool) {
        // Calculating commission
        uint256 deductedCommission = _amountOfTokens.mul(myMarketplaceStorage.commission).div(100);

        // Calculating amount to be paid to seller
        uint256 payOut = _amountOfTokens.sub(deductedCommission);

        // Transfering the tokens to seller
        require(myMarketplaceStorage.token.transfer(_sellerAddress, payOut));

        // Adding the commission to marketplace balance
        myMarketplaceStorage.commissionBalance = myMarketplaceStorage.commissionBalance.add(deductedCommission);

        return true;
    }
}
