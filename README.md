[![Review Assignment Due Date](https://classroom.github.com/assets/deadline-readme-button-22041afd0340ce965d47ae6ef1cefeee28c7c493a6346c4f15d667ab976d596c.svg)](https://classroom.github.com/a/Dueh7XgR)
## CSC 397/595 Hardware Design and Programming using FPGAs  
**Jarvis College of Computing and Digital Media - DePaul University**

This repository contains the source code and files for Lab Assignment 3.

### Software Requirements

This assignment is designed to run on a standard Ubuntu 24.04 LTS Server Edition OS. You will need to use **Make** (to run the provided Makefile), **Verilator** (to compile and simulate the Verilog files), and **Python 3.14** (to run the testing setup script).

To install the necessary software packages, including Python 3.14 from the deadsnakes PPA, open a terminal and run the following commands:

```shell
sudo apt update
sudo apt install -y software-properties-common
sudo add-apt-repository -y ppa:deadsnakes/ppa
sudo apt update
sudo apt install -y python3.14 make texinfo flex bison zlib1g-dev libgmp-dev libmpfr-dev ghdl verilator
```

### Setting up NEORV32 on Ubuntu 24.04 LTS

To set up the NEORV32 framework on a local installation of Ubuntu 24.04, you will need to first install the RISC V compiler toolchain. There are multiple approaches that you can follow, but the one listed in this documentation is the most stable.

Create a folder on your system where the compiler toolchain will be installed and make your user the ownwer of the folder. For example if your username is *alex* you can run:

```shell
sudo mkdir /opt/riscv
sudo chown alex:alex /opt/riscv
```

Clone and build the RISC V compiler toolchain:

```shell
git clone https://github.com/riscv/riscv-gnu-toolchain
cd riscv-gnu-toolchain
git checkout 2026.05.06
./configure --prefix=/opt/riscv --with-arch=rv32i --with-abi=ilp32
make -j NUM_CORES # replace NUM_CORES with the total number of cores that you would like to use to speed up the compilation
```

Add the compiler location to the environment:

```shell
sudo touch /etc/profile.d/riscv.sh
echo 'export PATH=/opt/riscv/bin:$PATH' | sudo tee /etc/profile.d/riscv.sh
sudo chmod 644 /etc/profile.d/riscv.sh
source /etc/profile.d/riscv.sh
```
