BUILD_DIR := build
BOOT_BIN := $(BUILD_DIR)/boot.bin
KERNEL_BIN := $(BUILD_DIR)/kernel.bin
IMAGE := $(BUILD_DIR)/utb_os.img

.PHONY: all clean run

all: $(IMAGE)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BOOT_BIN): boot.asm | $(BUILD_DIR)
	nasm -f bin $< -o $@

$(KERNEL_BIN): kernel.asm | $(BUILD_DIR)
	nasm -f bin $< -o $@

$(IMAGE): $(BOOT_BIN) $(KERNEL_BIN)
	cat $(BOOT_BIN) $(KERNEL_BIN) > $(IMAGE)
	truncate -s 1474560 $(IMAGE)

run: $(IMAGE)
	qemu-system-i386 -drive format=raw,file=$(IMAGE)

clean:
	rm -f $(BOOT_BIN) $(KERNEL_BIN) $(IMAGE)
