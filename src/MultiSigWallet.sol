// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract MultiSigWallet {
    event Deposit(address indexed sender, uint256 amount, uint256 balance);
    event Initiated(uint256 indexed txId, address indexed owner, address indexed to, uint256 value, bytes data);
    event Approved(uint256 indexed txId, address indexed owner);
    event Executed(uint256 indexed txId, address indexed owner);
    event Revoked(uint256 indexed txId, address indexed owner);

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
    }

    address[] public owners;
    uint256 public approvalsRequired;
    Transaction[] public transactions;

    mapping(address => bool) public isOwner;
    mapping(uint256 => mapping(address => bool)) public approvals;

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not owner");
        _;
    }

    modifier exists(uint256 _txId) {
        require(_txId < transactions.length, "Transaction does not exist");
        _;
    }

    modifier notApproved(uint256 _txId) {
        require(!approvals[_txId][msg.sender], "Already approved");
        _;
    }

    modifier notExecuted(uint256 _txId) {
        require(!transactions[_txId].executed, "Already executed");
        _;
    }

    constructor(address[] memory _owners, uint256 _approvalsRequired) {
        require(_owners.length > 0, "Not enough owners");
        require(_approvalsRequired > 0 && _approvalsRequired <= _owners.length, "Invalid amount of approvals");

        for (uint256 i; i < _owners.length; i++) {
            address owner = _owners[i];
            
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Duplicate owner");
            
            isOwner[owner] = true;
            owners.push(owner);
        }

        approvalsRequired = _approvalsRequired;
    }

    function initiate(address _to, uint256 _value, bytes calldata _data) public onlyOwner {
        transactions.push(Transaction(_to, _value, _data, false));
        emit Initiated(transactions.length - 1, msg.sender, _to, _value, _data);
    }

    function approve(uint256 _txId) public onlyOwner exists(_txId) notApproved(_txId) notExecuted(_txId) {
        approvals[_txId][msg.sender] = true;
        emit Approved(_txId, msg.sender);
    }

    function execute(uint256 _txId) public onlyOwner exists(_txId) notExecuted(_txId) {
        require(_getApprovalCount(_txId) >= approvalsRequired, "Insufficient approvals");
        require(address(this).balance >= transactions[_txId].value, "Insufficient balance");
        
        Transaction storage transaction = transactions[_txId];
        (bool success, ) = transaction.to.call{value: transaction.value}(transaction.data);
        
        require(success, "Transaction failed");

        transaction.executed = true;
        emit Executed(_txId, msg.sender);
    }

    function revoke(uint256 _txId) public onlyOwner exists(_txId) notExecuted(_txId) {
        approvals[_txId][msg.sender] = false;
        emit Revoked(_txId, msg.sender);
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getApprovalsRequired() public view returns (uint256) {
        return approvalsRequired;
    }

    function getTransactionCount() public view returns (uint256) {
        return transactions.length;
    }

    function getApprovalStatus(uint256 _txId) public view returns (bool) {
        return approvals[_txId][msg.sender];
    }

    function _getApprovalCount(uint256 _txId) private view returns (uint256 count) {
        for (uint256 i; i < owners.length; i++) {
            if (approvals[_txId][owners[i]]) {
                count++;
            }
        }
    }
}
