# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

Sandbox RTEMS 5 application ("RKI") for the Gaisler GR712RC (SPARC LEON3). The `Makefile` is the known-good baseline; the goal of the repo is to learn CMake by reproducing that build with CMake. When writing CMake, treat the `Makefile` as the spec: flags, link steps, and outputs should match it.

## Build commands (Makefile baseline)

Toolchain is Gaisler RCC 1.3.2 at `/opt/rcc-1.3.2` (`sparc-gaisler-rtems5-*`). It is not installed in the cloud container, so builds can only be verified on the user's machine.

```sh
make            # build _build/bin/rki.elf and rki.bin (BSP defaults to gr712rc; override with BSP=...)
make clean
make qemu       # run rki.elf in qemu-system-sparc -M leon3_generic
```

There are no tests or linters.

## Build pipeline details (what CMake must reproduce)

- Compile/link flags: `-mcpu=leon3 -ffunction-sections -fdata-sections`, plus `-B<rcc>/sparc-gaisler-rtems5/lib -B<rcc>/sparc-gaisler-rtems5/<BSP>/lib -specs bsp_specs -qrtems`. These `-B/-specs/-qrtems` flags are required at **both** compile and link time; the link goes through `gcc`, not `ld`. Link with `-Wl,--gc-sections` and `-lm`.
- Defines: `-D__SPARC__ -DHAVE_DLFCN_H=1 -DHAVE_RTEMS_PCI_H=1`; warnings `-Wall -Wno-address-of-packed-member`; `-g`; include `-Isrc`.
- Each C file emits an assembler listing to `_build/lis/<name>.lis` via `-Wa,-a=...`.
- Tar rootfs: `rootfs/` is tarred and turned into `tarfile.o` with `ld -r -b binary` (embedded file system image).
- Two-pass link for dynamic-loader symbols:
  1. link `rki.elf.pre` from objects + `tarfile.o`;
  2. `rtems-syms -e -c "<cflags>" -C <gcc> -o dl-sym.o rki.elf.pre` generates a symbol table object;
  3. relink `rki.elf` with `dl-sym.o` added;
  4. `objcopy -O binary --strip-all` → `rki.bin`, then `size`.
- Outputs go to `_build/bin/` (committed, including prebuilt artifacts) and `_build/lis/`. Intermediate objects are deleted after linking.

## Build directories

- `_build/` belongs to the root `Makefile` only; CMake must not write into it.
- The CMake build uses a separate `build/` directory (e.g. `cmake -S . -B build`), and its outputs (ELF, `.bin`, listings) should land under `build/`.

## Application architecture (`src/`)

- `rtems_config.h` holds the entire RTEMS `confdefs` configuration (task/semaphore limits, drivers, filesystems IMFS/RFS/MSDOS, shell commands, GRLIB driver manager incl. GRSPW2) and defines `CONFIGURE_INIT`. It must be included by exactly one translation unit — `rtemsInit.c`.
- `rtemsInit.c` contains the `Init` task: prints RTEMS info, calls `start_hello_task()`, then deletes itself. Calls to `rtems_setup_shell()` and `start_monitor_task()` are currently commented out (`start_monitor_task` has no implementation).
- `helloTask.c`: `start_hello_task()` creates task `HELO` at priority 122 (Init is 120), printing 10 times at 1 Hz.
- `rtemsShellSupport.c`: `rtems_setup_shell()` starts the RTEMS shell with local commands.
- Cross-file functions are declared with `extern` prototypes inside `rtemsInit.c` rather than in headers.
