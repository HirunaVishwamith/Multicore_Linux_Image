# RISC-V Emulator Setup and Build Guide

Welcome to the **RISC-V Emulator Setup and Build Guide**! This repository offers a detailed, step-by-step walkthrough for setting up a RISC-V emulator using QEMU, configuring the necessary build environment, and compiling critical components such as Buildroot, the Linux Kernel, and the RISC-V Proxy Kernel (riscv-pk). Whether you're a developer exploring RISC-V architecture or an enthusiast looking to emulate a RISC-V system, this guide will help you get started. Follow the instructions carefully to ensure a smooth and successful build process.

---

## Overview

The RISC-V architecture is an open-source instruction set architecture (ISA) gaining popularity for its flexibility and extensibility. This repository simplifies the process of setting up a RISC-V emulator by providing scripts, configurations, and instructions to build a fully functional emulated environment. By the end of this guide, you'll have:

- A minimal root filesystem generated with Buildroot.
- A compiled Linux kernel with RISC-V support.
- A RISC-V Proxy Kernel (riscv-pk) with the Berkeley Boot Loader (BBL).
- The ability to run the emulator using QEMU.

This guide assumes basic familiarity with Linux command-line operations and software compilation processes. Let’s dive in!

---

## Prerequisites

Before you begin, ensure your system meets the following requirements:

- **Operating System**: A Linux-based OS (Ubuntu is recommended for compatibility).
- **QEMU**: Installed for RISC-V emulation (e.g., `qemu-system-riscv64`).
- **Git**: For cloning the repository and managing submodules.
- **Buildroot**: Required to generate the root filesystem.
- **Cross-Compiler**: A RISC-V cross-compiler (e.g., `riscv64-buildroot-linux-uclibc-gcc`).
- **Dependencies**: Essential build tools like `make`, `gcc`, `g++`, `patch`, and others required by the kernel and Buildroot.

To install these on Ubuntu, you can run:

```
sudo apt update
sudo apt install git qemu-system build-essential bc libncurses-dev
```
Ensure all tools are up-to-date before proceeding.

Setup Instructions
Follow these steps to prepare your environment and fetch the necessary code.

1. Clone the Repository and Update Submodules
Start by cloning this repository to your local machine and updating its submodules:

```
git clone <repository_url>
cd <repository_name>
./submodule_update
```
Replace <repository_url> with the actual URL of this repository (e.g., https://github.com/username/riscv-emulator-guide.git).
Replace <repository_name> with the directory name created by the clone command.
The ./submodule_update script ensures all dependent submodules (e.g., Buildroot, Linux, riscv-pk) are downloaded and synchronized.
2. Set Up Environment Variables
Configure your environment variables to point to the correct tools and paths. Add the following lines to your ~/.bashrc file:

```
export RISCV=/path/to/buildroot/output/host
export PATH=$PATH:$RISCV/bin
export ARCH=riscv
export CROSS_COMPILE=riscv64-buildroot-linux-uclibc-
```
Important: Replace /path/to/buildroot/output/host with the actual path to your Buildroot output directory (e.g., /home/user/buildroot-2022.02.3/output/host). This path depends on where you install Buildroot and run its build process.
These variables set the RISC-V toolchain path, architecture, and cross-compiler prefix.
Apply the changes to your current session:

```
source ~/.bashrc
```
Verify the setup by running echo $RISCV and which riscv64-buildroot-linux-uclibc-gcc. You should see valid paths.

3. Apply Configurations and Patches
This repository includes a script to apply predefined configurations and patches to the components:

```
./apply_configs_and_patches
```
This script automates the process of configuring Buildroot, the Linux kernel, and riscv-pk with settings optimized for RISC-V emulation. Ensure it executes without errors before proceeding.

Building Components
Now, compile the individual components required for the emulator.

Buildroot
Buildroot generates a minimal root filesystem tailored for RISC-V:

```
cd buildroot
make -j16
```
Run this from the buildroot directory within the repository.
The -j16 flag parallelizes the build across 16 threads. Adjust this number based on your CPU cores (e.g., -j4 for 4 cores) to optimize build time.
The output will be in the output/ directory, including the host tools and root filesystem.

Linux Kernel
Compile the Linux kernel with RISC-V support:

```
cd linux
make -j16
```
Execute this from the linux directory.
This builds a kernel image (arch/riscv/boot/Image) compatible with RISC-V.
RISC-V Proxy Kernel (riscv-pk)
The RISC-V Proxy Kernel (riscv-pk) includes the Berkeley Boot Loader (BBL), which wraps the Linux kernel for execution:

```
cd riscv-pk
mkdir build
cd build
make
```
Run these commands from the riscv-pk directory.
The make command builds bbl, embedding the Linux kernel from ../linux/arch/riscv/boot/Image (assuming it’s already built).
After completion, the final Linux image is located at riscv-pk/build/bbl.
Configuring Linux Kernel for SMP
To enable Symmetric Multi-Processing (SMP) for multi-core support in the Linux kernel, follow these steps:

Navigate to the Linux Source Directory:
```
cd linux
```
Run Menuconfig:

```
make menuconfig
```
Enable SMP:
Navigate to Platform Type in the menu.
Enable Symmetric Multi-Processing (SMP).
Save the configuration and exit. This updates the .config file in the linux directory.
Integrate with Buildroot:
Move to the Buildroot directory:

```
cd ../buildroot
```
Open Buildroot’s menuconfig:
```
make menuconfig
```
Go to Kernel -> Linux Kernel.
Select the option to use a custom kernel configuration file.
Specify the path to the configuration file, such as ../linux/.config or a predefined file like ../../config_build_bbl (if provided in the repository).
Save and exit.
Rebuild the Kernel (if needed):

```
cd ../linux
make -j16
```
This ensures the kernel supports SMP when used with the emulator.

QEMU Default Configuration
To configure the Linux kernel with a default setup optimized for QEMU’s virt machine:

```
cd linux
make qemu_riscv64_virt_defconfig
```
Run this in the linux directory.
This command sets a predefined configuration suitable for running RISC-V Linux on QEMU. Rebuild the kernel (make -j16) if you apply this configuration after previous changes.
Generating and Editing Device Tree
The device tree describes the hardware configuration for the emulated RISC-V system. QEMU can generate a default device tree based on its virt machine, which you can modify as needed:

Generate the device tree during QEMU execution (covered in a potential usage section, not detailed here).
Edit the .dtb file using tools like dtc (Device Tree Compiler) if custom hardware changes are required.
For detailed instructions, consult the QEMU documentation or RISC-V resources.

Additional Notes
Path Adjustments: Double-check all paths (e.g., $RISCV) match your system’s setup. Incorrect paths are a common source of build errors.
Performance: The -j16 flag assumes a multi-core system. Use nproc to determine your core count and adjust accordingly (e.g., make -j$(nproc)).
Troubleshooting: If you encounter issues, verify tool versions, review error logs, or consult the official documentation for Buildroot, Linux, riscv-pk, and QEMU.
Next Steps: After building, you can run the emulator with QEMU. Example command (adjust paths as needed):

```
qemu-system-riscv64 -nographic -machine virt -kernel riscv-pk/build/bbl -append "root=/dev/vda ro" -drive file=buildroot/output/images/rootfs.ext2,format=raw,id=hd0 -device virtio-blk-device,drive=hd0
```
This README provides a foundation; expand it with usage instructions or advanced configurations as your project evolves.
