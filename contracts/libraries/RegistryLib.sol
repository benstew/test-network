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

library testRegistry {
    using SafeMath for uint;

    struct Skill {
        string skillName;
        string skilID;
        address skillOwner;
        uint256 stakedTokens;
        string state;
        Metainformation metainformation;
    }

    struct Metainformation {
        string description;
        string category;
        string seniority;
    }

    struct Validator {
        address validatorAddress;
        uint256 stakedTokens;
    }

    struct Arbiter {
        address arbiterAddress;
        uint256 stakedTokens;
    }

    struct RegistryStorage {

        string registryName;
        address testNetworkAddress;
        address testTokenAddress;
        address testVotingAddress;

        mapping (string => Skill) skills;
        mapping (address => string[]) skillsOfUser;
        mapping (address => uint) tokenBalance;
        mapping (address => Validator) validators;
        mapping (address => Arbiter) arbiters;
        mapping (address => uint) totalStakedTokens;

        // Count of Tokens that need to be staked
        uint256 tokenStakePerRegistration;
        uint256 tokenStakePerValidator;
        uint256 tokenStakePerArbiter;

        // Number of all active skills
        uint256 activeSkills;

        // Current activation state of the registry itself
        bool registryIsActive;

        // Owner of the registry
        address registryOwner;

        // Access to our token
        ERC20 token;
    }

    // Request access to the registry
    function requestRegistration(RegistryStorage storage myRegistryStorage, string _skillName, string _skillID, bytes32[] _skillMeta, address _sender) public returns (bool success){
        // Allocate new skill
        Skill memory newSkill;
        Metainformation memory newMetainformation;
        newSkill.metainformation = newMetainformation;

        // Add new skill to mapping
        myRegistryStorage.skills[_skillID] = newskill;

        // Adding skill id to the array of skills of a specific user
        myRegistryStorage.skillsOfUser[msg.sender].push(_skillID);

        // Setting basic values
        myRegistryStorage.skills[_skillID].skillName = _skillName;
        myRegistryStorage.skills[_skillID].skillID = _skillID;
        myRegistryStorage.skills[_skillID].skillOwner = _sender;
        myRegistryStorage.skills[_skillID].stakedTokens = 0;

        // If enough values are given, the information will be checked directly in this contract
        if(_skillMeta.length == 11) {
            require(validateRegistration(myRegistryStorage, _skillID, _skillMeta));
            if(stakeTokens(myRegistryStorage, _sender, _skillID, myRegistryStorage.tokenStakePerRegistration)) {
                myRegistryStorage.skills[_skillID].state = "accepted";
                myRegistryStorage.activeskills = myRegistryStorage.activeskills.add(1);
            } else {
                myRegistryStorage.skills[_skillID].state = "unproven";
            }

        // If only a hash (e.g. IPFS) is given, the request will be validated manually
        } else if(_skillMeta.length == 1) {
            myRegistryStorage.skills[_skillID].hashOfskillData = _skillMeta[0];
            myRegistryStorage.skills[_skillID].state = "unproven";
        } else {
            revert();
        }
        return true;
    }

    // Validate a registry-request with sufficient values
    function validateRegistration(RegistryStorage storage myRegistryStorage, string _skillID, bytes32[] _skillMeta) internal returns (bool success) {
        myRegistryStorage.skills[_skillID].metainformation.description = bytes32ToString(_skillMeta[0]);
        myRegistryStorage.skills[_skillID].metainformation.category = bytes32ToString(_skillMeta[1]);
        myRegistryStorage.skills[_skillID].metainformation.seniority = bytes32ToString(_skillMeta[2]);
        return true;
    }

    // Simulate approval [oraclize]
    function approveRegistrationRequest(RegistryStorage storage myRegistryStorage, string _skillID) public returns (bool success) {
        require(myRegistryStorage.skills[_skillID].stakedTokens == 0);
        require(stakeTokens(myRegistryStorage, myRegistryStorage.skills[_skillID].skillOwner, _skillID, myRegistryStorage.tokenStakePerRegistration));
        myRegistryStorage.skills[_skillID].state = "accepted";
        myRegistryStorage.activeskills = myRegistryStorage.activeskills.add(1);
        return true;
    }

    // Unregister skill
    function unregister(RegistryStorage storage myRegistryStorage, address _sender, string _skillID) public returns (bool) {
        require(keccak256(abi.encodePacked(myRegistryStorage.skills[_skillID].state)) == keccak256(abi.encodePacked("accepted")));
        require(unstakeTokens(myRegistryStorage, _sender, _skillID));
        delete myRegistryStorage.skills[_skillID];
        deleteFromArray(myRegistryStorage, _sender, _skillID);
        myRegistryStorage.activeskills = myRegistryStorage.activeskills.sub(1);
        return true;
    }

    // Stake tokens
    function stakeTokens(RegistryStorage storage myRegistryStorage, address _address, string _skillID, uint256 _numberOfTokens) internal returns (bool success) {
        myRegistryStorage.token.transferFrom(_address, address(this), _numberOfTokens);
        myRegistryStorage.skills[_skillID].stakedTokens = myRegistryStorage.skills[_skillID].stakedTokens.add(_numberOfTokens);
        myRegistryStorage.totalStakedTokens[_address] = myRegistryStorage.totalStakedTokens[_address].add(_numberOfTokens);
        return true;
    }

    // Unstake tokens
    function unstakeTokens(RegistryStorage storage myRegistryStorage, address _address, string _skillID) internal returns (bool success) {
        require(myRegistryStorage.skills[_skillID].stakedTokens > 0);
        require(myRegistryStorage.token.transfer(_address, myRegistryStorage.skills[_skillID].stakedTokens));
        myRegistryStorage.totalStakedTokens[_address] = myRegistryStorage.totalStakedTokens[_address].sub(myRegistryStorage.skills[_skillID].stakedTokens);
        myRegistryStorage.skills[_skillID].stakedTokens = myRegistryStorage.skills[_skillID].stakedTokens.sub(myRegistryStorage.skills[_skillID].stakedTokens);
        return true;
    }

    // Delete skill from user array
    function deleteFromArray(RegistryStorage storage myRegistryStorage, address _address, string _value) internal {
        require(myRegistryStorage.skillsOfUser[_address].length > 0);
        for(uint i = 0; i < myRegistryStorage.skillsOfUser[_address].length; i++) {
            if(keccak256(abi.encodePacked(myRegistryStorage.skillsOfUser[_address][i])) == keccak256(abi.encodePacked(_value))) {
                if(i != myRegistryStorage.skillsOfUser[_address].length-1) {
                    myRegistryStorage.skillsOfUser[_address][i] = myRegistryStorage.skillsOfUser[_address][myRegistryStorage.skillsOfUser[_address].length-1];
                }
                delete myRegistryStorage.skillsOfUser[_address][myRegistryStorage.skillsOfUser[_address].length-1];
                myRegistryStorage.skillsOfUser[_address].length--;
                break;
            }
        }
    }

    // Convert byte to string
    function bytes32ToString(bytes32 x) internal pure returns (string) {
        bytes memory bytesString = new bytes(32);
        uint charCount = 0;
        for (uint j = 0; j < 32; j++) {
            byte char = byte(bytes32(uint(x) * 2 ** (8 * j)));
            if (char != 0) {
                bytesString[charCount] = char;
                charCount++;
            }
        }
        bytes memory bytesStringTrimmed = new bytes(charCount);
        for (j = 0; j < charCount; j++) {
            bytesStringTrimmed[j] = bytesString[j];
        }
        return string(bytesStringTrimmed);
    }
}
