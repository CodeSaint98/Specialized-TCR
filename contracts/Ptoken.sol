//SPDX-License-Identifier: Unlicensed;
pragma solidity ^0.8.1;

// original gas cost was: 64298
// new gas cost is: 49816
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
contract PTokenBasic is ERC20{
    
    address public owner;

    constructor() ERC20( "PToken", "PT") 
    {
        owner = msg.sender;
        _mint(msg.sender, 1000000);
    }
}

contract owned{
    address admin;
    constructor(){
        admin = msg.sender;
    }
    modifier onlyOwner {
        require(msg.sender ==admin, "You do not have access to this functionality");
        _;
    }
}

contract PTokenCuratedRegistry is owned, PTokenBasic{
    PTokenBasic public ptoken;
    struct CandidateInfo {
        address owner;
        string link;
        uint8 voteCount;
        uint8 totalCount;
        uint256 stake; //total value of the proposal
        uint256 singleStake; //value of a single vote
        bool isListed;
    }
    
    struct Voter {
        uint8 weight;
        bool if_voted;
        address delegated_to;
        string stance;
        uint vote;
    }
    mapping(address => uint8) public indexOfListing;
    mapping(address => bool) public isWhale;
    mapping(address => Voter) public voters;
    mapping(address => uint256) public balance;
    address public ptokenaddress;
    CandidateInfo[10] public allCandidates;
    modifier onlyWhale(address _owner) {
        require(isWhale[_owner], "Error: This is not a whale account");
        _;
    }
    modifier onlyVoter(address _owner) {
        require(voters[_owner].weight>0, "A listee cannot vote or apply for whale account");
        _;
    }
    constructor(address contractCaller, address _ptokenaddress){
        ptokenaddress = _ptokenaddress;
        ptoken = PTokenBasic(ptokenaddress);
        balance[contractCaller] = ptoken.balanceOf(contractCaller);
        voters[contractCaller].weight = 1;
    }
    function getFreeListingIndex(address contractCaller) public view returns (uint8) {
        for (uint8 i =0; i<10; i++){
            if (allCandidates[i].owner == contractCaller){
                revert("Error: a single address cannot list more than one candidate");
            }
            
            if (allCandidates[i].isListed == false)
            return i;
        }
        revert("Error: no free listing");
    }
    
    function getListed(address contractCaller, string memory link) public payable{
        require(balance[contractCaller]>=10, "You must have enough tokens to pay the listing cost");
        uint8 freeIndex = getFreeListingIndex(contractCaller);
        indexOfListing[contractCaller] = freeIndex;
        balance[contractCaller] -=10;
        allCandidates[freeIndex].stake += 10;
        
        //filling in the details
        allCandidates[freeIndex].owner = contractCaller;
        allCandidates[freeIndex].link = link;
        allCandidates[freeIndex].voteCount = 1;
        voters[contractCaller].weight = 0;
        
    }
    
    function showListing(address contractCaller) public view returns(address, string memory, uint) {
        require(allCandidates[indexOfListing[contractCaller]].owner == contractCaller, "Listing does not exist");
        uint8 index1 = indexOfListing[contractCaller];
        return (allCandidates[index1].owner, allCandidates[index1].link, allCandidates[index1].stake);
    }
    
    function removeListing(address contractCaller, uint8 index) public {
        require(voters[contractCaller].weight==0, "Error: you must have a listing to remove one");
        balance[contractCaller] += 10;
        delete allCandidates[index];
        voters[contractCaller].weight = 1;
    }
    
    function ApplyVoter(address contractCaller) public{
        uint8 freeIndex = getFreeListingIndex(contractCaller);
        voters[contractCaller].weight = 1;
    }
    
    function ApplyWhale(address contractCaller) public onlyVoter(contractCaller){
        require(ptoken.balanceOf(contractCaller)>500, "You don't have enough Tokens to be a whale account");
        isWhale[contractCaller] = true;
        }
    function delegate(address contractCaller, address to) public onlyVoter(contractCaller) {
        require(isWhale[to], "This address is not a whale account");
        voters[contractCaller].weight -= 1;
        voters[to].weight += 1;
    }
    function castVote(address contractCaller, string memory _stance, uint8 index) public payable onlyVoter(contractCaller){
        require(index<11, "Listing does not exist");
        require(voters[contractCaller].weight>0, "You do not have right to vote");
        require(allCandidates[index].isListed!=true, "This listing is already in the registry");
        voters[contractCaller].stance = _stance;
        if(keccak256(abi.encodePacked(voters[contractCaller].stance)) == keccak256(abi.encodePacked("for"))){
         voters[contractCaller].vote += 1;
            allCandidates[index].voteCount +=1;
            allCandidates[index].totalCount +=1;
            allCandidates[index].stake += 5;
        }
        else{
           voters[contractCaller].vote += 1;
            allCandidates[index].voteCount -=1;
            allCandidates[index].stake += 5;
            allCandidates[index].totalCount +=1;
            
        }
    }
    
    function WhaleVote(address contractCaller, string memory _stance, uint8 index) public payable onlyVoter(contractCaller){
       require(index<11, "Listing does not exist");
        require(voters[contractCaller].weight>0, "You do not have right to vote");
        require(allCandidates[index].isListed!=true, "This listing is already in the registry");
        voters[contractCaller].stance = _stance;
        if(keccak256(abi.encodePacked(voters[contractCaller].stance)) == keccak256(abi.encodePacked("for"))){
            while(voters[contractCaller].weight!=0){
         voters[contractCaller].vote += 1;
            allCandidates[index].voteCount +=1;
            allCandidates[index].totalCount +=1;
            allCandidates[index].stake += 5;
            voters[contractCaller].weight -=1;
            }
        }
        else{
           voters[contractCaller].vote += 1;
            allCandidates[index].voteCount -=1;
            allCandidates[index].stake += 5;
            allCandidates[index].totalCount +=1;
            
        }
    }
    
    function endVote(address contractCaller, uint8 index) public{
        require(allCandidates[index].isListed == false, "no vote event available");

        if(allCandidates[index].voteCount>3){
            allCandidates[index].isListed = true;
            balance[contractCaller] += allCandidates[index].stake;
        }
        else
            removeListing(contractCaller, index);
    }
    
        
}