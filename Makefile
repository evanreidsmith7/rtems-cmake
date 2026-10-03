##
## RTEMS RKI2 makefile
##

##
## Architecture Definition
##
ARCH = sparc-gaisler-rtems5

##
## Select your BSP here
## 
BSP ?= gr712rc

##
## paths for the RTEMS tools and RTEMS BSP
##
RTEMS_TOOL_BASE = /opt/rcc-1.3.2
RTEMS_BSP_BASE = /opt/rcc-1.3.2

##
## Compiler paths
##
PREFIX         = $(RTEMS_TOOL_BASE)
RTEMS_PREFIX   = $(RTEMS_BSP_BASE)
RTEMS_ARCH_LIB = $(RTEMS_PREFIX)/$(ARCH)/$(BSP)/lib
RTEMS_ARCH_LIB2 = $(RTEMS_PREFIX)/$(ARCH)/lib
RTEMS_BIN		= $(RTEMS_PREFIX)/bin

##
## Path to install artifiacts
##
INSTALLPATH = ./_build/bin

##
## Linker flags
##
LDFLAGS ?= -mcpu=leon3 -ffunction-sections -fdata-sections -Wl,--gc-sections
LDFLAGS += --pipe -B$(RTEMS_ARCH_LIB2) -B$(RTEMS_ARCH_LIB) -specs bsp_specs -qrtems $(WARNINGS) 

##
## Compiler Architecture Switches
##
ARCH_OPTS ?= -mcpu=leon3 -ffunction-sections -fdata-sections -D__SPARC__
ARCH_OPTS += --pipe -B$(RTEMS_ARCH_LIB2) -B$(RTEMS_ARCH_LIB) -specs bsp_specs -qrtems
ARCH_OPTS += -DHAVE_DLFCN_H=1 -DHAVE_RTEMS_PCI_H=1

INCLUDE_PATH := -Isrc

WARNINGS = -Wall -Wno-address-of-packed-member
DEBUG_OPTS	 = -g 

##
## define build products
##
EXE_TARGET       = $(INSTALLPATH)/rki.elf
EXE_TARGET_PRE   = $(INSTALLPATH)/rki.elf.pre
BINARY_TARGET    = $(INSTALLPATH)/rki.bin
TAR_IMAGE        = tarfile.o
LINKSCRIPT       = linkcmds

##
## Objects to build
##
OBJS ?= rtemsInit.o
OBJS += rtemsShellSupport.o
OBJS += helloTask.o

##
## Libraries to link in
##
# LIBS = -Wl,-Bstatic -Wl,-Bdynamic -lm -lz
LIBS = -lm

##
## Optional libs depending on the features needed
##
# LIBS += -lftpd
# LIBS += -ltelnetd
# LIBS += -lnfs

##
## Extra Cflags for Assembly listings, etc.
##
LIST_OPTS    = -Wa,-a=_build/lis/$*.lis

##
## General gcc options that apply to compiling and dependency generation.
##
COPTS=$(LIST_OPTS) $(ARCH_OPTS) $(WARNINGS) $(INCLUDE_PATH)  -I.

##
## Extra defines and switches for assembly code
##
ASOPTS = -P -xassembler-with-cpp

####################################################
## Host Development System and Toolchain defintions
##
## Host OS utils
##
RM=rm -f
CP=cp
MV=mv
CD=cd
TAR=tar
CAT=cat
MKDIR=mkdir
LS=ls

##
## Compiler tools
##
COMPILER   = $(RTEMS_BIN)/$(ARCH)-gcc
ASSEMBLER  = $(RTEMS_BIN)/$(ARCH)-gcc
LINKER	   = $(RTEMS_BIN)/$(ARCH)-ld
AR	  	   = $(RTEMS_BIN)/$(ARCH)-ar
NM         = $(RTEMS_BIN)/$(ARCH)-nm
OBJCOPY    = $(RTEMS_BIN)/$(ARCH)-objcopy
SIZE       = $(RTEMS_BIN)/$(ARCH)-size

##
## RTEMS Specific host tools
##
RTEMS_SYMS = $(RTEMS_BIN)/rtems-syms

##
## VPATH
##
VPATH = src
###############################################################################################
##
## Build Targets
##

##
## The default "make" target is the subsystem object module.
##
default::$(EXE_TARGET)


#  Install rule is mission/target specific
#  install::$(EXE_TARGET)

##
## Compiler rule
##
.c.o:
	$(COMPILER)  $(COPTS) $(DEBUG_OPTS)  -c -o $@ $<

##
## Assembly Code Rule
##
.s.o:
	$(COMPILER) $(ASOPTS) $(COPTS) $(DEBUG_OPTS)  -c -o $@ $<

##
## Build Tar image
##
$(TAR_IMAGE)::
		$(MKDIR) -p rootfs
		$(CD) rootfs; $(TAR) cf ../tarfile .
		$(LINKER) -r --noinhibit-exec -o $(TAR_IMAGE) -b binary tarfile

##
## Link Rule to make the final executable image
## add symtab.o for symbol table
##
$(EXE_TARGET): $(OBJS) $(TAR_IMAGE)
	$(COMPILER) $(DEBUG_FLAGS) $(LDFLAGS) -o $(EXE_TARGET_PRE) $(OBJS) $(TAR_IMAGE) $(LIBS)
	$(RTEMS_SYMS) -v -e -c "-mcpu=leon3 -ffunction-sections -fdata-sections -Wl,--gc-sections" -C "$(COMPILER)" -o dl-sym.o $(EXE_TARGET_PRE)
	$(COMPILER) $(DEBUG_FLAGS) $(LDFLAGS) -o $(EXE_TARGET) $(OBJS) $(TAR_IMAGE) $(LIBS) dl-sym.o
	$(OBJCOPY) -O binary --strip-all $(EXE_TARGET) $(BINARY_TARGET)
	$(SIZE) $(EXE_TARGET)
	-$(RM) $(TAR_IMAGE) tarfile
	-$(RM) $(OBJS)
	-$(RM) dl-sym.o

##
## Make clean rule
##
clean::
	-$(RM) $(OBJS) $(EXE_TARGET) $(EXE_TARGET_PRE) $(BINARY_TARGET) 
	-$(RM) $(TAR_IMAGE) tarfile
	-$(RM) _build/lis/*.lis
	-$(RM) *.img
	-$(RM) dl-sym.o

qemu:
	qemu-system-sparc -M leon3_generic -m 128M \
		-nographic \
		-kernel $(EXE_TARGET)
