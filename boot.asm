[org 0x7C00]
[bits 16]

KERNEL_LOAD_SEGMENT equ 0x0000
KERNEL_LOAD_OFFSET  equ 0x8000
KERNEL_SECTORS      equ 16
STACK_TOP           equ 0x7C00
MAX_RETRIES         equ 3

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, STACK_TOP
    sti

    mov [boot_drive], dl

    mov si, msg_banner
    call print_string
    mov si, msg_loading
    call print_string

    call reset_disk
    jc disk_error

    mov bx, KERNEL_LOAD_OFFSET
    mov byte [current_sector], 2
    mov byte [sectors_left], KERNEL_SECTORS

load_loop:
    cmp byte [sectors_left], 0
    je boot_kernel

    mov byte [retry_counter], MAX_RETRIES
.read_attempt:
    mov ah, 0x02
    mov al, 0x01
    mov ch, 0x00
    mov cl, [current_sector]
    mov dh, 0x00
    mov dl, [boot_drive]
    int 0x13
    jnc .read_ok

    push ax
    call reset_disk
    pop ax
    dec byte [retry_counter]
    jnz .read_attempt
    mov [last_error_code], ah
    jmp disk_error

.read_ok:
    add bx, 512
    inc byte [current_sector]
    dec byte [sectors_left]
    jmp load_loop

boot_kernel:
    mov si, msg_ready
    call print_string
    mov dl, [boot_drive]
    jmp KERNEL_LOAD_SEGMENT:KERNEL_LOAD_OFFSET

reset_disk:
    mov ah, 0x00
    mov dl, [boot_drive]
    int 0x13
    ret

disk_error:
    mov si, msg_disk_error
    call print_string
    mov al, [last_error_code]
    call print_hex_byte
    mov si, msg_halt
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

print_hex_byte:
    push ax
    push bx
    mov bl, al
    shr al, 4
    call nibble_to_hex
    mov ah, 0x0E
    int 0x10
    mov al, bl
    and al, 0x0F
    call nibble_to_hex
    mov ah, 0x0E
    int 0x10
    pop bx
    pop ax
    ret

nibble_to_hex:
    and al, 0x0F
    cmp al, 9
    jbe .digit
    add al, 55
    ret
.digit:
    add al, '0'
    ret

msg_banner db 13, 10, 'UTB/OS bootloader v2', 13, 10, 0
msg_loading db 'Loading kernel sectors with retry guard...', 13, 10, 0
msg_ready db 'Kernel ready. Jumping to stage2.', 13, 10, 0
msg_disk_error db 'Disk read error, BIOS code=0x', 0
msg_halt db 13, 10, 'System halted.', 13, 10, 0
boot_drive db 0
current_sector db 0
sectors_left db 0
retry_counter db 0
last_error_code db 0

times 510 - ($ - $$) db 0
dw 0xAA55
