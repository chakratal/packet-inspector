---
title: Proof-of-Work Miner
---

# Lab Assignment 3: Proof-of-Work Miner

## 1. Overview

In this assignment, you will explore the powerful paradigm of **Hardware/Software Co-design**. You will implement a Proof-of-Work (PoW) mining application targeting the **NEORV32 RISC-V Processor**. 

You will be required to build two distinct solutions that accomplish the exact same task:
1. **A Software Implementation:** Written in C, running natively on the NEORV32 processor.
2. **A Hardware Accelerator:** Written in Verilog, designed as a custom memory-mapped peripheral connected to the NEORV32 through the XBUS interface.

By completing this lab, you will experience firsthand the performance advantages of offloading computationally intensive tasks (like cryptographic hashing) from software to a dedicated hardware accelerator.

## 2. The NEORV32 RISC-V SoC

The [**NEORV32**](https://github.com/stnolting/neorv32) is an open-source, highly customizable 32-bit RISC-V microcontroller System-on-Chip (SoC) written in platform-independent VHDL. It is designed to be easily deployed on FPGAs. 

Key features of the NEORV32 relevant to this lab include:
- **RISC-V CPU:** Executes standard 32-bit RISC-V instructions (`rv32i`). Your C code will be compiled using a RISC-V GCC toolchain and executed on this core.
- **External Bus Interface (XBUS):** A Wishbone-compatible bus interface that acts as a gateway to attach custom memory-mapped hardware. 

In standard software execution, the CPU fetches and executes instructions sequentially. While flexible, loops and bitwise operations take multiple clock cycles per iteration. By designing an XBUS-connected hardware accelerator, we can compute an entire hash and test a variable (a *nonce*) in a single clock cycle, vastly outperforming the software approach.

## 3. The Proof-of-Work Algorithm

Proof-of-Work is the consensus mechanism historically used by blockchain networks like Bitcoin. The goal is to find a specific number, called a **nonce**, such that when hashed together with a block of **data**, the resulting hash output is less than or equal to a specified **target** value.

For this lab, you will implement a simplified, custom 32-bit hash function.

### 3.1 Simple Hash Function

Given four 32-bit `data` integers and a 32-bit `nonce`, the hash is computed as follows:

```c
#include <stdint.h>

uint32_t simple_hash(uint32_t data0, uint32_t data1, uint32_t data2, uint32_t data3, uint32_t nonce) {
    uint32_t hash = data0 ^ data1 ^ data2 ^ data3 ^ nonce;
    
    // Circular left shift by 7 bits
    hash = (hash << 7) | (hash >> 25);
    
    // Add a magic constant
    hash = hash + 0xDEADBEEF;
    
    // XOR with a right-shifted nonce
    hash = hash ^ (nonce >> 1);
    
    return hash;
}
```

### 3.2 The Mining Objective

Your mining application (both software and hardware) must start with `nonce = 0` and increment the nonce by `1` until it finds the first nonce that satisfies the following condition:

`simple_hash(data0, data1, data2, data3, nonce) <= target`

Once found, the application must output (or return) this winning nonce.

## 4. Downloading the assignment

To start the lab, you must first accept the assignment in GitHub Classroom. Accepting the assignment on GitHub Classroom is a 2-step process:

- **Step 1:** click on the invitation link from the assignment description from D2L.
- **Step 2:** check the inbox of the email address that you used when you created your GitHub account (it will probably be your personal email address), and look for an invitation email from GitHub. Click accept.

Now you can clone your repository in your home directory on the **matrix.cdm.depaul.edu** machine (replace *USER* with your GitHub account name):

```shell
$ cd ~
$ git clone --recurse-submodules https://github.com/transcendental-software/csc-397-595-lab3-USER.git
```

This command creates a directory named `csc-397-595-lab3-USER` containing all the necessary files for the assignment. You can then navigate into it using `cd csc-397-595-lab3`. *You only need to modify* the `rtl/miner.v` and `src/main.c` files. Use the `make` command to compile your code and the `make test` to run all the tests.

## 5. Part 1: C Software Implementation

In the `src/` directory, you will find the `main.c` skeleton file. You need to implement the software mining routine.

### 5.1 Software Requirements

1. Implement the `simple_hash` function in C.
2. Implement the `mine_sw(uint32_t data0, uint32_t data1, uint32_t data2, uint32_t data3, uint32_t target)` function. This function should use a `while` or `for` loop to test nonces starting from `0`.
3. Inside the loop, compute the hash. If the hash is less than or equal to the `target`, break the loop and return the winning nonce.

You can compile and run your software test locally using the provided simulator script:

```shell
$ cd src
$ make sim
```

## 6. Part 2: Verilog Hardware Accelerator

In the `rtl/` directory, you will find the `miner.v` and `xbus_miner_wrapper.v` files. The XBUS communication is already implemented for you in the `xbus_miner_wrapper.v` module, which handles the memory-mapped register decoding. This allows you to focus strictly on the application logic within the `miner.v` file, where you must implement a Finite State Machine (FSM) that performs the mining process autonomously once triggered by the processor.

### 6.1 Memory-Mapped Registers (Implemented in Wrapper)

Your hardware module communicates with the NEORV32 using standard 32-bit memory-mapped registers over the XBUS. The `xbus_miner_wrapper.v` peripheral is mapped to a specific base address and decodes the lower address bits to interact with several internal registers. These registers are then passed as simple wire interfaces to your `miner.v` module:

| Offset | Register Name | Access | Description |
| :--- | :--- | :--- | :--- |
| `0x00` | `DATA0` | Write-only | Word 0 of the data block to hash. |
| `0x04` | `DATA1` | Write-only | Word 1 of the data block to hash. |
| `0x08` | `DATA2` | Write-only | Word 2 of the data block to hash. |
| `0x0C` | `DATA3` | Write-only | Word 3 of the data block to hash. |
| `0x10` | `TARGET`| Write-only | The 32-bit target threshold. |
| `0x14` | `CTRL` | Write/Read | **Write 1:** Start the miner.<br>**Read Bit 0:** `1` if busy, `0` if done. |
| `0x18` | `NONCE` | Read-only | The winning nonce (valid when busy is `0`). |

### 6.2 Miner Module Interface

Because the wrapper handles the complex bus transactions, the module template for your `miner` is significantly simplified. It receives the data and target directly, along with a `start` control signal, and it outputs the `busy` status and the discovered `nonce`:

```verilog
module miner (
    input  wire        clk,
    input  wire        reset,
    
    // Application Interface (from/to xbus_miner_wrapper)
    input  wire [31:0] data0,
    input  wire [31:0] data1,
    input  wire [31:0] data2,
    input  wire [31:0] data3,
    input  wire [31:0] target,
    input  wire        start,
    
    output reg         busy,
    output reg  [31:0] nonce
);
```

### 6.3 Hardware Mining FSM

Your accelerator must implement a sequential datapath:

1. **IDLE State:** Wait for the `start` signal to go high (`1`). The `start` signal acts as a trigger from the wrapper, pulsing high for one clock cycle when the CPU requests to start mining. When this happens, initialize your internal `nonce` counter to `0`, set the `busy` output to `1` (indicating to the wrapper and software that hashing is in progress), and move to the BUSY state.
2. **BUSY State:** 
    - On every clock cycle, calculate the `simple_hash` using the current data inputs (`data0` through `data3`) and the current `nonce`. Keep the `busy` signal set to `1`.
    - *Hint:* The hash calculation can be done purely using combinational logic (`wire` assignments) because it only involves bitwise shifts, XORs, and an addition.
    - If `hash <= target`, transition to the DONE state.
    - Otherwise, increment the `nonce` counter (`nonce <= nonce + 1`) and remain in the BUSY state.
3. **DONE State:** Deassert the `busy` signal (`busy = 0`). This communicates back to the wrapper and the software that the mining process is complete and the winning `nonce` is valid and ready to be read. The FSM can safely remain here or return to IDLE until a new `start` signal is received.

### 6.4 Testing the Hardware Miner

To verify your Verilog implementation, we have provided a hardware testbench.

```shell
$ cd src
$ make image install
$ cd ../rtl
$ make sim
```

You can debug your FSM states and the hash calculations using GTKWave:

```shell
$ gtkwave miner.vcd
```

## 7. Putting It Together (Co-design)

Once both `main.c` and `miner.v` are implemented, the final step in `main.c` is to write a routine that interacts with your custom Verilog hardware from C.

You will use pointer arithmetic in C to write to the XBUS addresses matching your hardware registers:

```c
#define MINER_BASE   0xF0000000U
#define MINER_DATA0  (*((volatile uint32_t*)(HW_MINER_BASE + 0x00)))
#define MINER_DATA1  (*((volatile uint32_t*)(HW_MINER_BASE + 0x04)))
#define MINER_DATA2  (*((volatile uint32_t*)(HW_MINER_BASE + 0x08)))
#define MINER_DATA3  (*((volatile uint32_t*)(HW_MINER_BASE + 0x0C)))
#define MINER_TARGET (*((volatile uint32_t*)(HW_MINER_BASE + 0x10)))
#define MINER_CTRL   (*((volatile uint32_t*)(HW_MINER_BASE + 0x14)))
#define MINER_NONCE  (*((volatile uint32_t*)(HW_MINER_BASE + 0x18)))

uint32_t mine_hw(uint32_t data0, uint32_t data1, uint32_t data2, uint32_t data3, uint32_t target) {
    // 1. Write data words and target to hardware
    HW_MINER_DATA0 = data0;
    HW_MINER_DATA1 = data1;
    HW_MINER_DATA2 = data2;
    HW_MINER_DATA3 = data3;
    HW_MINER_TARGET = target;
    
    // 2. Start the hardware miner
    HW_MINER_CTRL = 1;
    
    // 3. Poll the status register until busy bit is 0
    while (HW_MINER_CTRL & 1) {
        // Wait...
    }
    
    // 4. Return the found nonce
    return HW_MINER_NONCE;
}
```

When executed on the NEORV32 SoC, you will observe the software miner taking significantly longer to complete compared to the hardware accelerator, perfectly illustrating the value of FPGA hardware offloading.

## 8. Submitting Your Code

Once you have successfully passed both the software and hardware tests locally, push your code to your GitHub Classroom repository.

```shell
$ git add src/main.c rtl/miner.v
$ git commit -m "Completed PoW Miner Lab"
$ git push
```

Verify your submission on GitHub by checking the "Actions" tab to ensure all autograding checks pass correctly.