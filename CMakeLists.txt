# CMake build for the RKI RTEMS application (mirrors the root Makefile).
#
# Usage:
#   cmake -S . -B build          # configure (once)
#   cmake --build build          # build -> build/bin/rki.elf, rki.bin
#   cmake --build build -t qemu  # run in QEMU
#
# Override the BSP or toolchain location at configure time, e.g.:
#   cmake -S . -B build -DBSP=gr712rc -DRCC=/opt/rcc-1.3.2

cmake_minimum_required(VERSION 3.16)

# ---------------------------------------------------------------------------
# 1. Toolchain
#    These must be set BEFORE project(), because project() is where CMake
#    detects and tests the compiler.
# ---------------------------------------------------------------------------
set(RCC  "/opt/rcc-1.3.2" CACHE PATH   "RTEMS (Gaisler RCC) install directory")
set(BSP  "gr712rc"        CACHE STRING "RTEMS BSP")
set(ARCH "sparc-gaisler-rtems5")

set(CMAKE_SYSTEM_NAME Generic)              # cross-compiling, no host OS
set(CMAKE_C_COMPILER  ${RCC}/bin/${ARCH}-gcc)
# CMake's compiler check tries to link a test program; linking an RTEMS
# program needs our BSP flags, so only test that it can compile a library.
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

project(rki C)

# Other tools from the same toolchain
set(LD         ${RCC}/bin/${ARCH}-ld)
set(OBJCOPY    ${RCC}/bin/${ARCH}-objcopy)
set(SIZE       ${RCC}/bin/${ARCH}-size)
set(RTEMS_SYMS ${RCC}/bin/rtems-syms)

# Put final images in build/bin (keeps the Makefile's _build/ untouched)
set(BIN_DIR ${CMAKE_BINARY_DIR}/bin)
set(LIS_DIR ${CMAKE_BINARY_DIR}/lis)
file(MAKE_DIRECTORY ${BIN_DIR} ${LIS_DIR})

# ---------------------------------------------------------------------------
# 2. Flags shared by compiling AND linking (Makefile: ARCH_OPTS / LDFLAGS)
# ---------------------------------------------------------------------------
set(CPU_FLAGS -mcpu=leon3 -ffunction-sections -fdata-sections)
set(RTEMS_FLAGS
    -B${RCC}/${ARCH}/lib
    -B${RCC}/${ARCH}/${BSP}/lib
    -specs=bsp_specs
    -qrtems
)

# ---------------------------------------------------------------------------
# 3. Compile the sources once, into an OBJECT library.
#    Both link passes below reuse these same .o files.
# ---------------------------------------------------------------------------
set(SOURCES
    src/rtemsInit.c
    src/rtemsShellSupport.c
    src/helloTask.c
)

add_library(rki_objs OBJECT ${SOURCES})
target_include_directories(rki_objs PRIVATE src)
target_compile_definitions(rki_objs PRIVATE __SPARC__ HAVE_DLFCN_H=1 HAVE_RTEMS_PCI_H=1)
target_compile_options(rki_objs PRIVATE
    ${CPU_FLAGS} ${RTEMS_FLAGS}
    -Wall -Wno-address-of-packed-member
    -g
)

# Assembler listing per source file: build/lis/<name>.lis
foreach(src ${SOURCES})
    get_filename_component(name ${src} NAME_WE)
    set_source_files_properties(${src} PROPERTIES
        COMPILE_OPTIONS "-Wa,-a=${LIS_DIR}/${name}.lis")
endforeach()

# ---------------------------------------------------------------------------
# 4. Embedded root filesystem: rootfs/ -> tarfile -> tarfile.o
#    add_custom_command describes how to make a file; CMake runs it only
#    when something depends on that file (here: the executables below).
# ---------------------------------------------------------------------------
set(TAR_OBJ ${CMAKE_BINARY_DIR}/tarfile.o)
add_custom_command(
    OUTPUT  ${TAR_OBJ}
    COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_SOURCE_DIR}/rootfs
    COMMAND ${CMAKE_COMMAND} -E chdir ${CMAKE_SOURCE_DIR}/rootfs
            tar cf ${CMAKE_BINARY_DIR}/tarfile .
    COMMAND ${LD} -r --noinhibit-exec -o tarfile.o -b binary tarfile
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    COMMENT "Building embedded rootfs tarfile.o"
)

# Helper: link options used by both link passes
set(LINK_FLAGS ${CPU_FLAGS} -Wl,--gc-sections ${RTEMS_FLAGS} -Wall)

# ---------------------------------------------------------------------------
# 5. Link pass 1: rki.elf.pre (no symbol table yet)
# ---------------------------------------------------------------------------
add_executable(rki_pre $<TARGET_OBJECTS:rki_objs> ${TAR_OBJ})
target_link_options(rki_pre PRIVATE ${LINK_FLAGS})
target_link_libraries(rki_pre PRIVATE m)
set_target_properties(rki_pre PROPERTIES
    OUTPUT_NAME rki.elf.pre
    RUNTIME_OUTPUT_DIRECTORY ${BIN_DIR})

# Generate dl-sym.o (symbol table for the RTEMS dynamic loader) from pass 1
set(DLSYM_OBJ ${CMAKE_BINARY_DIR}/dl-sym.o)
add_custom_command(
    OUTPUT  ${DLSYM_OBJ}
    COMMAND ${RTEMS_SYMS} -v -e
            -c "-mcpu=leon3 -ffunction-sections -fdata-sections -Wl,--gc-sections"
            -C ${CMAKE_C_COMPILER}
            -o ${DLSYM_OBJ} $<TARGET_FILE:rki_pre>
    DEPENDS rki_pre
    COMMENT "Generating dl-sym.o with rtems-syms"
)

# ---------------------------------------------------------------------------
# 6. Link pass 2: rki.elf (same objects + dl-sym.o), then rki.bin
# ---------------------------------------------------------------------------
add_executable(rki $<TARGET_OBJECTS:rki_objs> ${TAR_OBJ} ${DLSYM_OBJ})
target_link_options(rki PRIVATE ${LINK_FLAGS})
target_link_libraries(rki PRIVATE m)
set_target_properties(rki PROPERTIES
    OUTPUT_NAME rki.elf
    RUNTIME_OUTPUT_DIRECTORY ${BIN_DIR})

# Runs after every link of rki
add_custom_command(TARGET rki POST_BUILD
    COMMAND ${OBJCOPY} -O binary --strip-all $<TARGET_FILE:rki> ${BIN_DIR}/rki.bin
    COMMAND ${SIZE} $<TARGET_FILE:rki>
)

# ---------------------------------------------------------------------------
# 7. Convenience target: cmake --build build -t qemu
# ---------------------------------------------------------------------------
add_custom_target(qemu
    COMMAND qemu-system-sparc -M leon3_generic -m 128M -nographic
            -kernel $<TARGET_FILE:rki>
    DEPENDS rki
    USES_TERMINAL
)
