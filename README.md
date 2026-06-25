# Multicore Supported Linux Image Creation for RISC‑V Processors

This repository provides a comprehensive, step‑by‑step guide to create a Linux image with multicore (SMP) support for RISC‑V processors. It details the process of setting up the build environment and compiling essential components such as Buildroot, a symmetric multi‑processing (SMP)‑enabled Linux kernel, and the RISC‑V Proxy Kernel (riscv‑pk) featuring the Berkeley Boot Loader (BBL). Whether you’re a developer exploring the RISC‑V architecture or an enthusiast seeking to emulate a many‑core environment, this documentation will help you get started quickly and efficiently.

---

## Overview

The RISC‑V architecture is an open‑source instruction set known for its flexibility and extensibility. This repository simplifies the process of creating a fully functional, emulated environment for many‑core RISC‑V systems by providing ready‑to‑use scripts, configurations, and detailed instructions. By following this guide, you will:

- Generate a minimal root filesystem using Buildroot.
- Compile an SMP‑enabled Linux kernel with native multicore support.
- Build the RISC‑V Proxy Kernel (riscv‑pk) integrated with the Berkeley Boot Loader (BBL).
- Run the resulting image on a custom‑made many‑core RISC‑V processor or within an emulated environment.

Prerequisites: Basic familiarity with Linux command‑line operations and software compilation is assumed.

---

## Getting Started

### 1. Clone the Repository and Update Submodules
Begin by cloning the repository and synchronizing its submodules, which include Buildroot, the Linux kernel, and riscv‑pk:

```
git clone <repository_url>
cd ./Multicore_Linux_Image
./submodule_update
```
Replace <repository_url> with the actual URL of this repository (e.g., `git@github.com:HirunaVishwamith/Multicore_Linux_Image.git`). The `./submodule_update` script downloads and synchronizes all dependent submodules.
### 2. Set Up Environment Variables
Configure your environment by adding the necessary variables to your `~/.bashrc` file:

```
export RISCV=/home/vithurson/buildroot-2022.02.3/output/host
export PATH=$PATH:$RISCV/bin
export ARCH=riscv export CROSS_COMPILE=riscv64-buildroot-linux-uclibc-

generic
```
After updating your `~/.bashrc`, run the configuration script and source the file:

```
./apply_configs_and_patches
source ~/.bashrc
```
This step automatically configures Buildroot, the Linux kernel, and riscv‑pk for RISC‑V emulation. Make sure that the script completes without errors before proceeding.

## Building Components

## Buildroot
Buildroot generates a minimal root filesystem tailored for RISC‑V:

```
cd buildroot
make -j16
```
Run this from the buildroot directory within the repository.
The -j16 flag parallelizes the build across 16 threads. Adjust this number based on your CPU cores (e.g., -j4 for 4 cores) to optimize build time.
The output will be in the output/ directory, including the host tools and root filesystem.

## Linux Kernel
Compile the Linux kernel with RISC-V support:

```
cd linux
make -j16
```

Run Menuconfig:

```
make menuconfig
```
In the menu, navigate to **Platform Type** and enable **Symmetric Multi‑Processing (SMP)**. Save and exit to update the `.config` file.

![smp_enabled](doc/2.png)



## Integrate with Buildroot:

Move to the Buildroot directory:

```
cd ../buildroot
```
Open Buildroot’s menuconfig:
```
make menuconfig
```
Go to `Kernel -> Linux Kernel` and select the option to use a custom kernel configuration file. Provide the path to the Linux kernel configuration (e.g., `../linux/.config`). Save your changes. 

![add_linux_kernal](doc/1.png)

Rebuild the Kernel:

```
make -j16
```
This builds a kernel image (arch/riscv/boot/Image) compatible with Multicore RISC-V suport.

## RISC‑V Proxy Kernel (riscv‑pk)

Execute this from the linux directory.

The RISC-V Proxy Kernel (riscv-pk) includes the Berkeley Boot Loader (BBL), which wraps the Linux kernel for execution:

```
cd riscv-pk
mkdir build
cd build
make
```

This will compile riscv‑pk and produce the BBL executable.

## Generating the Multicore‑Supported Device Tree

To create a device tree file tailored for a multicore Linux image, configure the Linux kernel with a default setup optimized for QEMU’s virt machine:


```
cd linux
make qemu_riscv64_virt_defconfig
```

Then integrate this `.cofig` with the buildroot and `make` it again. Then `make` the `build`

To generate the device tree file, run QEMU with the following command:

```
qemu-system-riscv64 -nographic -machine virt -kernel ../riscv-pk/build/bbl -append "root=/dev/vda ro" -drive file=../buildroot/output/images/rootfs.ext2,format=raw,id=hd0 -device virtio-blk-device,drive=hd0
```

This command boots the multicore‑supported Linux image using the compiled BBL, allowing QEMU to generate the necessary device tree.

---

## Building images for the chiron processor (no‑MMU, RAM @ `0x80000000`)

chiron is a **no‑MMU, machine‑mode** RISC‑V core: it has a `satp` CSR but performs **no address translation** (no page‑table walk / TLB in either the golden‑model emulator or the RTL). Therefore only a **nommu, M‑mode** kernel can run on it, and its DRAM lives at **`0x80000000`** (the golden model services a 144 MB window `[0x80000000, 0x89000000)`). The generic steps above target a machine with RAM at `0x10000000`; the steps below produce images that boot on chiron. Both the golden emulator and the RTL load a **flat binary at `0x80000000`** — so the deliverable is `bbl.bin` (bbl + nommu‑kernel payload + embedded dtb), `objcopy`‑ed to a raw binary.

The kernel/buildroot/riscv‑pk configs in `configs/` already select `CONFIG_RISCV_M_MODE=y` / `# CONFIG_MMU is not set`. After `./apply_configs_and_patches`, apply these chiron‑specific changes.

### 1. Relocate the kernel to `0x80000000`

`CONFIG_PAGE_OFFSET` (the nommu RAM/link base) defaults to `0x10200000`. Point it at chiron's RAM by editing `linux/arch/riscv/Kconfig`:

```
config PAGE_OFFSET
	hex
	default 0x80200000 if 64BIT && !MMU   # was 0x10200000
```

Then `cd linux && make olddefconfig` and confirm `CONFIG_PAGE_OFFSET=0x80200000`.

### 2. Device tree (`device_tree/sample.dts`, single‑core)

- `memory@0x80000000` size must fit the emulator's window — use **128 MB**: `reg = <0x0 0x80000000 0x0 0x08000000>;`
- Console must be the uartlite (an M‑mode kernel has no SBI, so `console=hvc0` is silent). Set:
  ```
  chosen { bootargs = "earlycon=uartlite,0x40600000 console=ttyUL0 root=/dev/ram rw rootfstype=ramfs"; };
  ```
- The full uartlite driver needs `current-speed` **and** an interrupt, so the uart node needs `current-speed = <115200>;` and an `interrupt-parent`/`interrupts` pointing at a PLIC node (`sifive,plic-1.0.0` at `0xc000000`, `interrupts-extended = <&cpu0_intc 11>`). See `device_tree/sample.dts`.

Enable the console drivers in the kernel: `CONFIG_SERIAL_UARTLITE_CONSOLE=y`, `CONFIG_SERIAL_EARLYCON=y`.

### 3. Patch the uartlite driver for poll‑drained TX

chiron has no wired uartlite interrupt, so the IRQ‑driven TX path stalls userspace output after the FIFO fills. Make `ulite_start_tx()` (in `linux/drivers/tty/serial/uartlite.c`) drain the whole ring — safe on real HW too:

```c
static void ulite_start_tx(struct uart_port *port)
{
	while (ulite_transmit(port, uart_in32(ULITE_STATUS, port)))
		;
}
```

### 4. Build vmlinux + bbl + flat image

```
cd linux && make -j$(nproc) vmlinux            # entry should be 0x80200000
cd ../riscv-pk && mkdir -p build && cd build
../configure --prefix=$RISCV --host=riscv64-buildroot-linux-uclibc \
  --with-arch=rv64ima --with-abi=lp64 --with-mem-start=0x80000000 \
  --with-payload=../../linux/vmlinux --with-dts=../../device_tree/sample.dts \
  --enable-print-device-tree --disable-vm --enable-boot-machine
make                                           # produces bbl + bbl.bin (flat @ 0x80000000)
```

`bbl.bin` is the bootable single‑core image. Stage it into chiron's `bins/` (e.g. `bins/linux-s1.bin`).

### 5. Quad‑core (SMP) image

```
cd linux && ./scripts/config --enable CONFIG_SMP --set-val CONFIG_NR_CPUS 4
make olddefconfig && make -j$(nproc) vmlinux
```

Use a 4‑CPU device tree (`device_tree/sample_quad.dts`: `cpu@0..cpu@3`, each with its own `cpu-intc`; the CLINT and PLIC `interrupts-extended` list every hart), then rebuild bbl with `--with-dts=../../device_tree/sample_quad.dts`. Stage as `bins/linux-q4.bin`.

### 6. Run on chiron

From the chiron repo root:

```
make linux-emu       LINUX_IMAGE=bins/linux-s1.bin   # boot on the golden emulator
make linux-lockstep  LINUX_IMAGE=bins/linux-s1.bin   # bounded RTL-vs-emulator lock-step
```

(`scripts/run_linux.sh` stages the image into `sim/data/Image`, runs, and reports PASS/mismatch.)

### Known limitations

- **Interactive input** isn't wired in the golden model's UART RX, so the boot reaches `buildroot login:` but you can't type into it.
- **Quad‑core SMP** boots to userspace but only **CPU 0 comes online** — the golden model's CLINT models a single shared `mtimecmp` and no per‑hart software‑interrupt (MSIP) IPI, so secondaries can't be released. On the RTL it's additionally blocked by the known CCU/L2 multi‑core deadlock.

## Conclusion

By following these instructions, you will have successfully built a multicore‑supported Linux image for RISC‑V processors. This setup enables you to experiment with a fully functional, emulated many‑core RISC‑V environment or deploy the image on custom hardware. For further details or troubleshooting, consult the repository’s additional documentation and support channels.

Happy building!

