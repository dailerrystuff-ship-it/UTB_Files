[org 0x7C00]
[bits 16]

KERNEL_LOAD_SEGMENT equ 0x0000
KERNEL_LOAD_OFFSET  equ 0x8000
KERNEL_SECTORS      equ 16

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti

    mov [boot_drive], dl

    mov si, msg_loading
    call print_string

    mov ah, 0x02
    mov al, KERNEL_SECTORS
    mov ch, 0x00
    mov cl, 0x02
    mov dh, 0x00
    mov dl, [boot_drive]
    mov bx, KERNEL_LOAD_OFFSET
    int 0x13
    jc disk_error

    jmp KERNEL_LOAD_SEGMENT:KERNEL_LOAD_OFFSET

disk_error:
    mov si, msg_disk_error
    call print_string
.hang:
    cli
    hlt
    jmp .hang

print_string:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0E
    mov bh, 0x00
    mov bl, 0x0F
    int 0x10
    jmp print_string
.done:
    ret

msg_loading db 'UTB/OS bootloader: loading kernel...', 13, 10, 0
msg_disk_error db 'Disk read error.', 13, 10, 0
boot_drive db 0

times 510 - ($ - $$) db 0
dw 0xAA55
