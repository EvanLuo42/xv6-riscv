K = kernel
U = user

BIN = bin
OBJ = obj

OBJS = $(patsubst $K/%.c,$(OBJ)/%.o,$(wildcard $K/*.c))
OBJS += $(patsubst $K/%.s,$(OBJ)/%.o,$(wildcard $K/*.s))

ifndef TOOLPREFIX
TOOLPREFIX := $(shell if riscv64-unknown-elf-objdump -i 2>&1 | grep 'elf64-big' >/dev/null 2>&1; \
	then echo 'riscv64-unknown-elf-'; \
	elif riscv64-linux-gnu-objdump -i 2>&1 | grep 'elf64-big' >/dev/null 2>&1; \
	then echo 'riscv64-linux-gnu-'; \
	elif riscv64-unknown-linux-gnu-objdump -i 2>&1 | grep 'elf64-big' >/dev/null 2>&1; \
	then echo 'riscv64-unknown-linux-gnu-'; \
	else echo "***" 1>&2; \
	echo "*** Error: Couldn't find a riscv64 version of GCC/binutils." 1>&2; \
	echo "*** To turn off this error, run 'gmake TOOLPREFIX= ...'." 1>&2; \
	echo "***" 1>&2; exit 1; fi)
endif

QEMU = qemu-system-riscv64

CC = $(TOOLPREFIX)gcc
AS = $(TOOLPREFIX)as
LD = $(TOOLPREFIX)ld
OBJCOPY = $(TOOLPREFIX)objcopy
OBJDUMP = $(TOOLPREFIX)objdump
LLDB = lldb

CFLAGS = -Wall -Werror -O -fno-omit-frame-pointer -ggdb -gdwarf-2
CFLAGS += -MD
CFLAGS += -mcmodel=medany
# CFLAGS += -ffreestanding -fno-common -nostdlib -mno-relax
CFLAGS += -fno-common -nostdlib
CFLAGS += -fno-builtin-strncpy -fno-builtin-strncmp -fno-builtin-strlen -fno-builtin-memset
CFLAGS += -fno-builtin-memmove -fno-builtin-memcmp -fno-builtin-log -fno-builtin-bzero
CFLAGS += -fno-builtin-strchr -fno-builtin-exit -fno-builtin-malloc -fno-builtin-putc
CFLAGS += -fno-builtin-free
CFLAGS += -fno-builtin-memcpy -Wno-main
CFLAGS += -fno-builtin-printf -fno-builtin-fprintf -fno-builtin-vprintf
CFLAGS += -I.
CFLAGS += $(shell $(CC) -fno-stack-protector -E -x c /dev/null >/dev/null 2>&1 && echo -fno-stack-protector)

LDFLAGS = -z max-page-size=4096

QEMU = qemu-system-riscv64
QFLAGS = -machine virt 
QFLAGS += -nographic 
QFLAGS += -bios bootloader/rustsbi-qemu.bin
QFLAGS += -device loader,file=bin/kernel,addr=0x80200000
QFLAGS += -s -S

all: $(BIN)/kernel.bin

$(BIN)/kernel.bin: $(OBJS) $(OBJ) $(BIN) $K/kernel.ld
	$(LD) $(LDFLAGS) -T $K/kernel.ld -o $(BIN)/kernel $(OBJS)
	$(OBJDUMP) -S $(BIN)/kernel > $(BIN)/kernel.asm
	$(OBJDUMP) -t $(BIN)/kernel | sed '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > $(BIN)/kernel.sym

$(OBJ)/%.o: $K/%.s | $(OBJ)
	$(AS) -c -o $@ $<

$(OBJ)/%.o: $K/%.c | $(OBJ)
	$(CC) $(CFLAGS) -c -o $@ $<

$(BIN):
	mkdir -p $(BIN)

$(OBJ):
	mkdir -p $(OBJ)

qemu: $(BIN)/kernel
	$(QEMU) $(QFLAGS)

debug: $(BIN)/kernel
	$(LLDB) $(BIN)/kernel --one-line "gdb-remote localhost:1234"
	
clean: $(BIN) $(OBJ)
	rm -r $(BIN) $(OBJ)