// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract MultiSigWallet {
    event Deposit(address indexed sender, uint amount, uint balance);
    event Initiated(uint indexed txId, address indexed owner, address indexed to, uint value, bytes data);
    event Approved(uint indexed txId, address indexed owner);
    event Executed(uint indexed txId, address indexed owner);
    event Revoked(uint indexed txId, address indexed owner);

    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
    }

    address[] public owners;
    uint public approvalsRequired;
    Transaction[] public transactions;

    mapping(address => bool) public isOwner;
    mapping(uint => mapping(address => bool)) public approvals;

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not owner");
        _;
    }

    modifier exists(uint _txId) {
        require(_txId < transactions.length, "Transaction does not exist");
        _;
    }

    modifier notApproved(uint _txId) {
        require(!approvals[_txId][msg.sender], "Already approved");
        _;
    }

    modifier notExecuted(uint _txId) {
        require(!transactions[_txId].executed, "Already executed");
        _;
    }

    constructor(address[] memory _owners, uint _approvalsRequired) {
        require(_owners.length > 0, "Not enough owners");
        require(_approvalsRequired > 0 && _approvalsRequired <= _owners.length, "Invalid amount of approvals");

        for (uint i; i < _owners.length; i++) {
            address owner = _owners[i];
            
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Duplicate owner");
            
            isOwner[owner] = true;
            owners.push(owner);
        }

        approvalsRequired = _approvalsRequired;
    }

    function initiate(address _to, uint _value, bytes calldata _data) public onlyOwner {
        transactions.push(Transaction(_to, _value, _data, false));
        emit Initiated(transactions.length - 1, msg.sender, _to, _value, _data);
    }

    function approve(uint _txId) public onlyOwner exists(_txId) notApproved(_txId) notExecuted(_txId) {
        approvals[_txId][msg.sender] = true;
        emit Approved(_txId, msg.sender);
    }

    function execute(uint _txId) public onlyOwner exists(_txId) notExecuted(_txId) {
        require(_getApprovalCount(_txId) >= approvalsRequired, "Insufficient approvals");
        require(address(this).balance >= transactions[_txId].value, "Insufficient balance");
        
        Transaction storage transaction = transactions[_txId];
        (bool success, ) = transaction.to.call{value: transaction.value}(transaction.data);
        
        require(success, "Transaction failed");

        transaction.executed = true;
        emit Executed(_txId, msg.sender);
    }

    function revoke(uint _txId) public onlyOwner exists(_txId) notExecuted(_txId) {
        approvals[_txId][msg.sender] = false;
        emit Revoked(_txId, msg.sender);
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getApprovalsRequired() public view returns (uint) {
        return approvalsRequired;
    }

    function getTransactionCount() public view returns (uint) {
        return transactions.length;
    }

    function getApprovalStatus(uint _txId) public view returns (bool) {
        return approvals[_txId][msg.sender];
    }

    function _getApprovalCount(uint _txId) private view returns (uint count) {
        for (uint i; i < owners.length; i++) {
            if (approvals[_txId][owners[i]]) {
                count++;
            }
        }
    }
}
