[org 0x8000]
[bits 16]

VIDEO_SEGMENT    equ 0xB800
SCREEN_COLS      equ 80
SCREEN_ROWS      equ 25
BACKGROUND_ATTR  equ 0x10
PANEL_ATTR       equ 0x1F
WINDOW_ATTR      equ 0x17
WINDOW_FILL_ATTR equ 0x11
SELECTED_ATTR    equ 0x3F
TEXT_ATTR        equ 0x1F
MUTED_ATTR       equ 0x18
ACCENT_ATTR      equ 0x1E
GOOD_ATTR        equ 0x2E
WARN_ATTR        equ 0x4E
HELP_ATTR        equ 0x30
BAR_EMPTY_ATTR   equ 0x18
BAR_FILL_ATTR    equ 0x2A

selected_app db 1
show_help db 0
boot_drive_value db 0
last_ascii db '-'
last_scan db 0
conv_mem_kb dw 0
equipment_word dw 0
timer_low dw 0
video_mode db 0
video_cols db 0
video_page db 0
rtc_century db 0
rtc_year db 0
rtc_month db 0
rtc_day db 0
rtc_hour db 0
rtc_minute db 0
rtc_second db 0
status_message_ptr dw status_ready
number_buffer times 6 db 0
hex_buffer db '00', 0
hex16_buffer db '0000', 0
bcd_buffer db '00', 0
rect_row db 0
rect_col db 0
rect_height db 0
rect_width db 0
rect_attr db 0
row_counter db 0
col_counter db 0
last_col db 0
last_row db 0
bar_width db 0
bar_fill db 0

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
    call refresh_metrics
    mov word [status_message_ptr], status_ready

main_loop:
    call render_desktop
    xor ah, ah
    int 0x16
    mov [last_ascii], al
    mov [last_scan], ah

    cmp al, '1'
    je select_shell
    cmp al, '2'
    je select_monitor
    cmp al, '3'
    je select_profile
    cmp al, 'h'
    je toggle_help
    cmp al, 'H'
    je toggle_help
    cmp al, 'r'
    je refresh_all
    cmp al, 'R'
    je refresh_all
    cmp ah, 0x4B
    je select_prev
    cmp ah, 0x4D
    je select_next
    cmp al, 27
    je reboot_system

    mov word [status_message_ptr], status_unknown_key
    jmp main_loop

select_shell:
    mov byte [selected_app], 1
    mov word [status_message_ptr], status_shell
    jmp main_loop

select_monitor:
    mov byte [selected_app], 2
    mov word [status_message_ptr], status_monitor
    jmp main_loop

select_profile:
    mov byte [selected_app], 3
    mov word [status_message_ptr], status_profile
    jmp main_loop

select_prev:
    mov al, [selected_app]
    cmp al, 1
    jne .dec
    mov byte [selected_app], 3
    jmp .done
.dec:
    dec byte [selected_app]
.done:
    mov word [status_message_ptr], status_cycle
    jmp main_loop

select_next:
    mov al, [selected_app]
    cmp al, 3
    jne .inc
    mov byte [selected_app], 1
    jmp .done
.inc:
    inc byte [selected_app]
.done:
    mov word [status_message_ptr], status_cycle
    jmp main_loop

toggle_help:
    xor byte [show_help], 1
    mov al, [show_help]
    cmp al, 0
    jne .on
    mov word [status_message_ptr], status_help_off
    jmp main_loop
.on:
    mov word [status_message_ptr], status_help_on
    jmp main_loop

refresh_all:
    call refresh_metrics
    mov word [status_message_ptr], status_refresh
    jmp main_loop

reboot_system:
    int 0x19
    jmp main_loop

refresh_metrics:
    int 0x12
    mov [conv_mem_kb], ax

    int 0x11
    mov [equipment_word], ax

    mov ah, 0x0F
    int 0x10
    mov [video_mode], al
    mov [video_cols], ah
    mov [video_page], bh

    xor ah, ah
    int 0x1A
    mov [timer_low], dx

    mov ah, 0x04
    int 0x1A
    jc .skip_date
    mov [rtc_century], ch
    mov [rtc_year], cl
    mov [rtc_month], dh
    mov [rtc_day], dl
.skip_date:
    mov ah, 0x02
    int 0x1A
    jc .done
    mov [rtc_hour], ch
    mov [rtc_minute], cl
    mov [rtc_second], dh
.done:
    ret

render_desktop:
    call clear_screen
    call draw_background
    call draw_top_bar
    call draw_windows
    call draw_titles
    call draw_shell_window
    call draw_monitor_window
    call draw_profile_window
    call draw_footer
    mov al, [show_help]
    cmp al, 0
    je .done
    call draw_help_overlay
.done:
    ret

clear_screen:
    mov ax, (BACKGROUND_ATTR << 8) | ' '
    xor di, di
    mov cx, SCREEN_COLS * SCREEN_ROWS
    rep stosw
    ret

draw_background:
    mov dh, 1
.bg_row:
    cmp dh, 24
    jnb .done
    mov dl, 0
.bg_col:
    cmp dl, SCREEN_COLS
    jnb .next_row
    mov al, '.'
    test dl, 1
    jz .draw
    mov al, ':'
.draw:
    mov bl, MUTED_ATTR
    call put_char_at
    inc dl
    jmp .bg_col
.next_row:
    inc dh
    jmp .bg_row
.done:
    ret

draw_top_bar:
    mov dh, 0
    mov dl, 0
    mov ch, 1
    mov cl, 80
    mov bl, PANEL_ATTR
    call fill_rect

    PRINT 0, 2, TEXT_ATTR, title_bar
    PRINT 0, 33, MUTED_ATTR, title_subtitle
    PRINT 0, 60, GOOD_ATTR, rtc_label

    mov al, [rtc_hour]
    mov dh, 0
    mov dl, 65
    mov bl, GOOD_ATTR
    call print_bcd_byte_at
    PRINT 0, 67, GOOD_ATTR, colon_text
    mov al, [rtc_minute]
    mov dh, 0
    mov dl, 68
    mov bl, GOOD_ATTR
    call print_bcd_byte_at
    PRINT 0, 70, GOOD_ATTR, colon_text
    mov al, [rtc_second]
    mov dh, 0
    mov dl, 71
    mov bl, GOOD_ATTR
    call print_bcd_byte_at

    mov al, [rtc_day]
    mov dh, 0
    mov dl, 74
    mov bl, TEXT_ATTR
    call print_bcd_byte_at
    PRINT 0, 76, TEXT_ATTR, slash_text
    mov al, [rtc_month]
    mov dh, 0
    mov dl, 77
    mov bl, TEXT_ATTR
    call print_bcd_byte_at
    ret

draw_windows:
    ; Left shell window
    mov dh, 2
    mov dl, 1
    mov ch, 18
    mov cl, 39
    mov bl, WINDOW_ATTR
    call draw_panel_box

    ; Top-right monitor
    mov dh, 2
    mov dl, 41
    mov ch, 10
    mov cl, 38
    mov bl, WINDOW_ATTR
    call draw_panel_box

    ; Bottom-right profile
    mov dh, 13
    mov dl, 41
    mov ch, 10
    mov cl, 38
    mov bl, WINDOW_ATTR
    call draw_panel_box
    ret

draw_panel_box:
    push bx
    push cx
    push dx
    push bx
    call draw_box
    pop bx
    pop dx
    pop cx
    pop bx

    push bx
    mov bl, WINDOW_FILL_ATTR
    inc dh
    inc dl
    sub ch, 2
    sub cl, 2
    call fill_rect
    pop bx
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
    PRINT 8, 3, ACCENT_ATTR, shell_line_5
    PRINT 9, 3, TEXT_ATTR, shell_line_6
    PRINT 10, 3, MUTED_ATTR, shell_line_7
    PRINT 11, 3, MUTED_ATTR, shell_line_8
    PRINT 12, 3, TEXT_ATTR, shell_line_9
    PRINT 13, 3, MUTED_ATTR, shell_line_10
    PRINT 14, 3, GOOD_ATTR, shell_line_11
    PRINT 15, 3, MUTED_ATTR, shell_line_12
    PRINT 16, 3, TEXT_ATTR, status_label
    mov dh, 16
    mov dl, 11
    mov bl, GOOD_ATTR
    mov si, [status_message_ptr]
    call print_string_at
    PRINT 17, 3, TEXT_ATTR, last_key_label
    mov dh, 17
    mov dl, 13
    mov bl, ACCENT_ATTR
    mov al, [last_ascii]
    cmp al, 32
    jb .non_printable
    cmp al, 126
    ja .non_printable
    call put_char_at
    jmp .scan
.non_printable:
    mov al, '.'
    call put_char_at
.scan:
    PRINT 17, 16, TEXT_ATTR, scan_label
    mov al, [last_scan]
    mov dh, 17
    mov dl, 22
    mov bl, ACCENT_ATTR
    call print_hex8_at
    ret

draw_monitor_window:
    PRINT 4, 43, TEXT_ATTR, monitor_line_1
    PRINT 5, 43, MUTED_ATTR, monitor_line_2
    PRINT 6, 43, TEXT_ATTR, monitor_line_3
    mov ax, [conv_mem_kb]
    mov dh, 6
    mov dl, 62
    mov bl, GOOD_ATTR
    call print_decimal_at
    PRINT 6, 66, GOOD_ATTR, kb_suffix

    PRINT 7, 43, TEXT_ATTR, monitor_line_4
    mov al, [boot_drive_value]
    mov dh, 7
    mov dl, 55
    mov bl, ACCENT_ATTR
    call print_hex8_at

    PRINT 8, 43, TEXT_ATTR, monitor_line_5
    mov al, [video_mode]
    mov dh, 8
    mov dl, 55
    mov bl, ACCENT_ATTR
    call print_hex8_at
    PRINT 8, 58, MUTED_ATTR, cols_label
    xor ax, ax
    mov al, [video_cols]
    mov dh, 8
    mov dl, 67
    mov bl, GOOD_ATTR
    call print_decimal_at

    PRINT 9, 43, TEXT_ATTR, monitor_line_6
    mov ax, [equipment_word]
    mov dh, 9
    mov dl, 54
    mov bl, ACCENT_ATTR
    call print_hex16_at

    PRINT 10, 43, TEXT_ATTR, memory_bar_label
    mov ax, [conv_mem_kb]
    cmp ax, 640
    jbe .mem_ok
    mov ax, 640
.mem_ok:
    xor dx, dx
    mov bx, 20
    mul bx
    mov bx, 640
    div bx
    mov [bar_fill], al
    mov byte [bar_width], 20
    mov dh, 10
    mov dl, 58
    call draw_progress_bar
    ret

draw_profile_window:
    PRINT 15, 43, TEXT_ATTR, profile_line_1
    PRINT 16, 43, ACCENT_ATTR, profile_line_2
    PRINT 17, 43, ACCENT_ATTR, profile_line_3
    PRINT 18, 43, ACCENT_ATTR, profile_line_4
    PRINT 19, 43, ACCENT_ATTR, profile_line_5
    PRINT 20, 43, ACCENT_ATTR, profile_line_6
    PRINT 21, 43, MUTED_ATTR, profile_line_7
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
    PRINT 24, 63, SELECTED_ATTR, footer_shell
    ret
.not_shell:
    cmp al, 2
    jne .not_monitor
    PRINT 24, 61, SELECTED_ATTR, footer_monitor
    ret
.not_monitor:
    PRINT 24, 61, SELECTED_ATTR, footer_profile
    ret

draw_help_overlay:
    mov dh, 6
    mov dl, 18
    mov ch, 11
    mov cl, 44
    mov bl, HELP_ATTR
    call draw_panel_box

    PRINT 7, 21, SELECTED_ATTR, help_title
    PRINT 9, 21, TEXT_ATTR, help_line_1
    PRINT 10, 21, TEXT_ATTR, help_line_2
    PRINT 11, 21, TEXT_ATTR, help_line_3
    PRINT 12, 21, TEXT_ATTR, help_line_4
    PRINT 13, 21, TEXT_ATTR, help_line_5
    PRINT 14, 21, MUTED_ATTR, help_line_6
    PRINT 15, 21, MUTED_ATTR, help_line_7
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
    push ax
    push bx
    push cx
    push dx
    push di

    cmp dh, SCREEN_ROWS
    jnb .out
    cmp dl, SCREEN_COLS
    jnb .out

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
.out:
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
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
    cmp dl, SCREEN_COLS
    jb .next
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

; Input AL=byte, output string at DH/DL/BL
print_hex8_at:
    push ax
    push si
    mov ah, al
    shr al, 4
    call nibble_to_hex
    mov [hex_buffer], al
    mov al, ah
    and al, 0x0F
    call nibble_to_hex
    mov [hex_buffer + 1], al
    mov si, hex_buffer
    call print_string_at
    pop si
    pop ax
    ret

; Input AX=word, output string at DH/DL/BL
print_hex16_at:
    push ax
    push bx
    push dx
    push si

    mov bx, ax
    mov al, bh
    shr al, 4
    call nibble_to_hex
    mov [hex16_buffer], al
    mov al, bh
    and al, 0x0F
    call nibble_to_hex
    mov [hex16_buffer + 1], al
    mov al, bl
    shr al, 4
    call nibble_to_hex
    mov [hex16_buffer + 2], al
    mov al, bl
    and al, 0x0F
    call nibble_to_hex
    mov [hex16_buffer + 3], al
    mov si, hex16_buffer
    call print_string_at

    pop si
    pop dx
    pop bx
    pop ax
    ret

; Inputs: AL=packed BCD, DH/DL/BL position/attr
print_bcd_byte_at:
    push ax
    push si
    mov ah, al
    shr al, 4
    and al, 0x0F
    add al, '0'
    mov [bcd_buffer], al
    mov al, ah
    and al, 0x0F
    add al, '0'
    mov [bcd_buffer + 1], al
    mov si, bcd_buffer
    call print_string_at
    pop si
    pop ax
    ret

draw_progress_bar:
    mov [rect_row], dh
    mov [rect_col], dl
    mov byte [col_counter], 0
.loop:
    mov al, [col_counter]
    cmp al, [bar_width]
    jnb .done
    mov dh, [rect_row]
    mov dl, [rect_col]
    add dl, [col_counter]
    mov al, 219
    mov bl, BAR_EMPTY_ATTR
    mov ah, [col_counter]
    cmp ah, [bar_fill]
    jnb .draw
    mov bl, BAR_FILL_ATTR
.draw:
    call put_char_at
    inc byte [col_counter]
    jmp .loop
.done:
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

title_bar db 'UTB/OS :: enhanced BIOS real-mode system', 0
title_subtitle db 'safe boot  live monitor  asm only', 0
rtc_label db 'RTC', 0
colon_text db ':', 0
slash_text db '/', 0
shell_title db ' System Shell ', 0
monitor_title db ' Monitor ', 0
profile_title db ' Profile Inspector ', 0
shell_line_1 db 'utb-shell 0.2  ::  guarded boot complete', 0
shell_line_2 db 'boot> sector loader uses BIOS retry guard', 0
shell_line_3 db 'boot> renderer clips writes to screen edges', 0
shell_line_4 db 'boot> metrics refreshed from BIOS + RTC', 0
shell_line_5 db 'Shortcuts: 1/2/3, arrows, H, R, Esc', 0
shell_line_6 db 'Apps: shell / monitor / profile', 0
shell_line_7 db 'Design: layered panels + highlighted focus', 0
shell_line_8 db 'Safety: bounded draw routine + disk reset', 0
shell_line_9 db 'Status message:', 0
shell_line_10 db 'Last key and scan code:', 0
shell_line_11 db 'Next step: protected mode + IRQ keyboard', 0
shell_line_12 db 'Tip: press H for quick help overlay', 0
status_label db 'status: ', 0
last_key_label db 'key: ', 0
scan_label db 'scan=', 0
monitor_line_1 db 'Conventional memory:', 0
monitor_line_2 db 'Live values come from BIOS services', 0
monitor_line_3 db 'Boot drive:', 0
monitor_line_4 db 'Video mode:', 0
monitor_line_5 db 'Equipment word:', 0
monitor_line_6 db 'Memory headroom', 0
cols_label db 'cols:', 0
kb_suffix db 'KB', 0
memory_bar_label db '640KB', 0
profile_line_1 db 'Embedded snapshot', 0
profile_line_2 db '{ "Profile": {', 0
profile_line_3 db '  "BootMode": "BIOS16",', 0
profile_line_4 db '  "UILayer": "VGA text",', 0
profile_line_5 db '  "Safety": ["retry", "bounds"],', 0
profile_line_6 db '  "Next": "pmode, irq, fs"', 0
profile_line_7 db '} }', 0
footer_left db '1/2/3 select  <- -> cycle  H help  R refresh  Esc reboot', 0
footer_shell db 'shell active', 0
footer_monitor db 'monitor active', 0
footer_profile db 'profile active', 0
help_title db ' Quick Help ', 0
help_line_1 db '1 / 2 / 3   - choose window', 0
help_line_2 db 'Left / Right - cycle active window', 0
help_line_3 db 'R            - refresh BIOS metrics', 0
help_line_4 db 'H            - show or hide this help', 0
help_line_5 db 'Esc          - reboot through BIOS', 0
help_line_6 db 'Unknown keys are ignored but logged below.', 0
help_line_7 db 'This overlay is drawn by the kernel itself.', 0
status_ready db 'system ready', 0
status_shell db 'shell selected', 0
status_monitor db 'monitor selected', 0
status_profile db 'profile selected', 0
status_cycle db 'window cycled', 0
status_help_on db 'help overlay enabled', 0
status_help_off db 'help overlay hidden', 0
status_refresh db 'metrics refreshed', 0
status_unknown_key db 'unknown key ignored', 0

times 8192 - ($ - $$) db 0
