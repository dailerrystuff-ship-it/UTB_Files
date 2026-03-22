[org 0x8000]
[bits 16]

VIDEO_SEGMENT  equ 0xB800
SCREEN_COLS    equ 80
SCREEN_ROWS    equ 25
PANEL_ATTR     equ 0x1B
WINDOW_ATTR    equ 0x17
SELECTED_ATTR  equ 0x2F
TEXT_ATTR      equ 0x1F
MUTED_ATTR     equ 0x17
ACCENT_ATTR    equ 0x3F
GOOD_ATTR      equ 0x2E

selected_app db 1
boot_drive_value db 0
conv_mem_kb dw 0
number_buffer times 6 db 0
hex_buffer db '00', 0
rect_row db 0
rect_col db 0
rect_height db 0
rect_width db 0
rect_attr db 0
row_counter db 0
col_counter db 0
last_col db 0
last_row db 0

%macro PRINT 4
    mov dh, %1
    mov dl, %2
    mov bl, %3
    mov si, %4
    call print_string_at
%endmacro

start:
    cli
    xor ax, ax
    mov ds, ax
    mov ax, VIDEO_SEGMENT
    mov es, ax
    sti

    mov [boot_drive_value], dl
    int 0x12
    mov [conv_mem_kb], ax

main_loop:
    call render_desktop
    xor ah, ah
    int 0x16
    cmp al, '1'
    je .shell
    cmp al, '2'
    je .monitor
    cmp al, '3'
    je .profile
    cmp al, 'r'
    je .redraw
    cmp al, 'R'
    je .redraw
    cmp al, 27
    je .reboot
    jmp main_loop
.shell:
    mov byte [selected_app], 1
    jmp main_loop
.monitor:
    mov byte [selected_app], 2
    jmp main_loop
.profile:
    mov byte [selected_app], 3
    jmp main_loop
.redraw:
    jmp main_loop
.reboot:
    int 0x19
    jmp main_loop

render_desktop:
    call clear_screen

    mov dh, 0
    mov dl, 0
    mov ch, 1
    mov cl, 80
    mov bl, PANEL_ATTR
    call fill_rect

    PRINT 0, 2, TEXT_ATTR, title_bar
    PRINT 0, 45, MUTED_ATTR, title_hint

    mov dh, 2
    mov dl, 1
    mov ch, 18
    mov cl, 39
    mov bl, WINDOW_ATTR
    call draw_box

    mov dh, 2
    mov dl, 41
    mov ch, 10
    mov cl, 38
    mov bl, WINDOW_ATTR
    call draw_box

    mov dh, 13
    mov dl, 41
    mov ch, 10
    mov cl, 38
    mov bl, WINDOW_ATTR
    call draw_box

    call draw_titles
    call draw_shell_window
    call draw_monitor_window
    call draw_profile_window
    call draw_footer
    ret

clear_screen:
    mov ax, 0x0720
    xor di, di
    mov cx, SCREEN_COLS * SCREEN_ROWS
    rep stosw
    ret

draw_titles:
    mov al, [selected_app]
    cmp al, 1
    jne .shell_plain
    PRINT 2, 3, SELECTED_ATTR, shell_title
    jmp .monitor_title
.shell_plain:
    PRINT 2, 3, TEXT_ATTR, shell_title
.monitor_title:
    mov al, [selected_app]
    cmp al, 2
    jne .monitor_plain
    PRINT 2, 43, SELECTED_ATTR, monitor_title
    jmp .profile_title
.monitor_plain:
    PRINT 2, 43, TEXT_ATTR, monitor_title
.profile_title:
    mov al, [selected_app]
    cmp al, 3
    jne .profile_plain
    PRINT 13, 43, SELECTED_ATTR, profile_title
    ret
.profile_plain:
    PRINT 13, 43, TEXT_ATTR, profile_title
    ret

draw_shell_window:
    PRINT 4, 3, TEXT_ATTR, shell_line_1
    PRINT 5, 3, MUTED_ATTR, shell_line_2
    PRINT 6, 3, MUTED_ATTR, shell_line_3
    PRINT 7, 3, MUTED_ATTR, shell_line_4
    PRINT 8, 3, TEXT_ATTR, shell_line_5
    PRINT 9, 3, MUTED_ATTR, shell_line_6
    PRINT 10, 3, TEXT_ATTR, shell_line_7
    PRINT 11, 3, MUTED_ATTR, shell_line_8
    PRINT 12, 3, MUTED_ATTR, shell_line_9
    PRINT 13, 3, TEXT_ATTR, shell_line_10
    PRINT 14, 3, MUTED_ATTR, shell_line_11
    PRINT 15, 3, MUTED_ATTR, shell_line_12
    PRINT 16, 3, MUTED_ATTR, shell_line_13
    PRINT 17, 3, MUTED_ATTR, shell_line_14
    ret

draw_monitor_window:
    PRINT 4, 43, TEXT_ATTR, monitor_line_1
    PRINT 5, 43, MUTED_ATTR, monitor_line_2
    PRINT 6, 43, MUTED_ATTR, monitor_line_3
    PRINT 7, 43, TEXT_ATTR, monitor_line_4
    PRINT 8, 43, GOOD_ATTR, usable_label

    mov ax, [conv_mem_kb]
    mov dh, 8
    mov dl, 51
    mov bl, GOOD_ATTR
    call print_decimal_at
    PRINT 8, 55, GOOD_ATTR, kb_suffix

    PRINT 9, 43, ACCENT_ATTR, drive_label
    mov al, [boot_drive_value]
    mov ah, al
    shr al, 4
    call nibble_to_hex
    mov [hex_buffer], al
    mov al, ah
    and al, 0x0F
    call nibble_to_hex
    mov [hex_buffer + 1], al
    PRINT 9, 55, ACCENT_ATTR, hex_prefix
    mov dh, 9
    mov dl, 57
    mov bl, ACCENT_ATTR
    mov si, hex_buffer
    call print_string_at

    PRINT 10, 43, MUTED_ATTR, monitor_line_5
    ret

draw_profile_window:
    PRINT 15, 43, TEXT_ATTR, profile_line_1
    PRINT 16, 43, ACCENT_ATTR, profile_line_2
    PRINT 17, 43, ACCENT_ATTR, profile_line_3
    PRINT 18, 43, ACCENT_ATTR, profile_line_4
    PRINT 19, 43, ACCENT_ATTR, profile_line_5
    PRINT 20, 43, ACCENT_ATTR, profile_line_6
    PRINT 21, 43, ACCENT_ATTR, profile_line_7
    ret

draw_footer:
    mov dh, 24
    mov dl, 0
    mov ch, 1
    mov cl, 80
    mov bl, PANEL_ATTR
    call fill_rect

    PRINT 24, 2, TEXT_ATTR, footer_left
    mov al, [selected_app]
    cmp al, 1
    jne .not_shell
    PRINT 24, 65, SELECTED_ATTR, footer_shell
    ret
.not_shell:
    cmp al, 2
    jne .not_monitor
    PRINT 24, 63, SELECTED_ATTR, footer_monitor
    ret
.not_monitor:
    PRINT 24, 63, SELECTED_ATTR, footer_profile
    ret

; Inputs: DH=row, DL=col, CH=height, CL=width, BL=attr
fill_rect:
    mov [rect_row], dh
    mov [rect_col], dl
    mov [rect_height], ch
    mov [rect_width], cl
    mov [rect_attr], bl
    mov byte [row_counter], 0
.row_loop:
    mov byte [col_counter], 0
.col_loop:
    mov dh, [rect_row]
    add dh, [row_counter]
    mov dl, [rect_col]
    add dl, [col_counter]
    mov al, ' '
    mov bl, [rect_attr]
    call put_char_at
    inc byte [col_counter]
    mov al, [col_counter]
    cmp al, [rect_width]
    jb .col_loop
    inc byte [row_counter]
    mov al, [row_counter]
    cmp al, [rect_height]
    jb .row_loop
    ret

; Inputs: DH=row, DL=col, CH=height, CL=width, BL=attr
draw_box:
    mov [rect_row], dh
    mov [rect_col], dl
    mov [rect_height], ch
    mov [rect_width], cl
    mov [rect_attr], bl

    mov al, [rect_width]
    dec al
    mov [last_col], al
    mov al, [rect_height]
    dec al
    mov [last_row], al

    mov dh, [rect_row]
    mov dl, [rect_col]
    mov bl, [rect_attr]
    mov al, 201
    call put_char_at

    mov dh, [rect_row]
    mov dl, [rect_col]
    add dl, [last_col]
    mov bl, [rect_attr]
    mov al, 187
    call put_char_at

    mov byte [col_counter], 1
.top_loop:
    mov al, [col_counter]
    cmp al, [last_col]
    jnb .sides
    mov dh, [rect_row]
    mov dl, [rect_col]
    add dl, [col_counter]
    mov bl, [rect_attr]
    mov al, 205
    call put_char_at
    inc byte [col_counter]
    jmp .top_loop

.sides:
    mov byte [row_counter], 1
.side_loop:
    mov al, [row_counter]
    cmp al, [last_row]
    jnb .bottom
    mov dh, [rect_row]
    add dh, [row_counter]
    mov dl, [rect_col]
    mov bl, [rect_attr]
    mov al, 186
    call put_char_at

    mov dh, [rect_row]
    add dh, [row_counter]
    mov dl, [rect_col]
    add dl, [last_col]
    mov bl, [rect_attr]
    mov al, 186
    call put_char_at

    inc byte [row_counter]
    jmp .side_loop

.bottom:
    mov dh, [rect_row]
    add dh, [last_row]
    mov dl, [rect_col]
    mov bl, [rect_attr]
    mov al, 200
    call put_char_at

    mov dh, [rect_row]
    add dh, [last_row]
    mov dl, [rect_col]
    add dl, [last_col]
    mov bl, [rect_attr]
    mov al, 188
    call put_char_at

    mov byte [col_counter], 1
.bottom_loop:
    mov al, [col_counter]
    cmp al, [last_col]
    jnb .done
    mov dh, [rect_row]
    add dh, [last_row]
    mov dl, [rect_col]
    add dl, [col_counter]
    mov bl, [rect_attr]
    mov al, 205
    call put_char_at
    inc byte [col_counter]
    jmp .bottom_loop
.done:
    ret

; Inputs: DH=row, DL=col, AL=char, BL=attr
put_char_at:
    push bx
    push cx
    push dx
    push di

    mov ch, al
    mov cl, bl
    xor ax, ax
    mov al, dh
    mov bl, SCREEN_COLS
    mul bl
    xor bx, bx
    mov bl, dl
    add ax, bx
    shl ax, 1
    mov di, ax
    mov al, ch
    mov ah, cl
    mov [es:di], ax

    pop di
    pop dx
    pop cx
    pop bx
    ret

; Inputs: DH=row, DL=col, BL=attr, SI=string
print_string_at:
.next:
    lodsb
    or al, al
    jz .done
    push dx
    call put_char_at
    pop dx
    inc dl
    jmp .next
.done:
    ret

; Inputs: AX=number, DH=row, DL=col, BL=attr
print_decimal_at:
    push ax
    push bx
    push dx
    push si

    mov si, number_buffer + 5
    mov byte [si], 0
    mov bx, 10
    dec si
    cmp ax, 0
    jne .convert
    mov byte [si], '0'
    jmp .print
.convert:
.convert_loop:
    xor dx, dx
    div bx
    add dl, '0'
    mov [si], dl
    dec si
    cmp ax, 0
    jne .convert_loop
    inc si
.print:
    call print_string_at

    pop si
    pop dx
    pop bx
    pop ax
    ret

nibble_to_hex:
    cmp al, 9
    jbe .digit
    add al, 55
    ret
.digit:
    add al, '0'
    ret

title_bar db 'UTB/OS :: BIOS real-mode prototype', 0
title_hint db '[1][2][3] switch  [Esc] reboot', 0
shell_title db ' System Shell ', 0
monitor_title db ' Monitor ', 0
profile_title db ' Profile Inspector ', 0
shell_line_1 db 'UTB shell 0.1', 0
shell_line_2 db 'boot> stage2 from raw sectors', 0
shell_line_3 db 'boot> video: VGA text 80x25', 0
shell_line_4 db 'boot> input: BIOS int 16h', 0
shell_line_5 db 'user@utb:/ $ help', 0
shell_line_6 db ' 1 shell  2 monitor  3 profile', 0
shell_line_7 db 'user@utb:/ $ apps', 0
shell_line_8 db ' monitor: mem + boot drive', 0
shell_line_9 db ' profile: embedded json', 0
shell_line_10 db 'user@utb:/ $ about', 0
shell_line_11 db ' BIOS boot, no host OS', 0
shell_line_12 db ' asm only, inspectable core', 0
shell_line_13 db ' next: pmode + irq + fs', 0
shell_line_14 db ' Esc to reboot', 0
monitor_line_1 db 'video: direct VGA text write', 0
monitor_line_2 db 'input: BIOS int 16h polling', 0
monitor_line_3 db 'loop: render -> key -> redraw', 0
monitor_line_4 db 'conventional memory:', 0
usable_label db 'usable:', 0
kb_suffix db 'KB', 0
drive_label db 'boot drive:', 0
hex_prefix db '0x', 0
monitor_line_5 db 'next: int13 fs + pmode', 0
profile_line_1 db 'Embedded ProfileTemplate:', 0
profile_line_2 db '{ "Profile": {', 0
profile_line_3 db '  "OwnedCharacters": {},', 0
profile_line_4 db '  "Coins": 0,', 0
profile_line_5 db '  "RedeemedCodes": {},', 0
profile_line_6 db '  "LastExitReason": "None"', 0
profile_line_7 db '} }', 0
footer_left db '1 Shell  2 Monitor  3 Profile  R Redraw  Esc Reboot', 0
footer_shell db 'shell', 0
footer_monitor db 'monitor', 0
footer_profile db 'profile', 0

times 8192 - ($ - $$) db 0
