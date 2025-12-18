; ==============================================================================
; Script de Limpeza de Alta Performance - Startup (Low Level)
; Compilação: nasm -f win64 clean_temp_x64.asm -o clean_temp_x64.obj
; Linkagem:   ld clean_temp_x64.obj -lkernel32 -o clean_temp.exe --subsystem windows
; ==============================================================================
bits 64
default rel

segment .data
    temp_env    db "TEMP", 0

    win_temp_path db "C:\Windows\Temp", 0
    win_temp_mask db "C:\Windows\Temp\*", 0

    wildcard    db "\*", 0
    dot         db ".", 0
    dotdot      db "..", 0

segment .bss
    temp_path   resb 264
    search_mask resb 264
    file_path   resb 264

    current_base resq 1
    find_data:
        dwFileAttributes    resd 1
        ftCreationTime      resq 1
        ftLastAccessTime    resq 1
        ftLastWriteTime     resq 1
        nFileSizeHigh       resd 1
        nFileSizeLow        resd 1
        dwReserved0         resd 1
        dwReserved1         resd 1
        cFileName           resb 260
        cAlternateFileName  resb 14

segment .text
    extern GetEnvironmentVariableA
    extern FindFirstFileA
    extern FindNextFileA
    extern FindClose
    extern DeleteFileA
    extern RemoveDirectoryA
    extern ExitProcess
    extern lstrcatA
    extern lstrcpyA

    global _start

_start:
    sub rsp, 40

    ; --- PASSO 1: Limpar %TEMP% do Usuário ---
    lea rcx, [temp_env]
    lea rdx, [temp_path]
    mov r8, 260
    call GetEnvironmentVariableA
    test rax, rax
    jz .try_windows_temp

    lea rcx, [temp_path]
    lea rdx, [search_mask]
    call prepare_mask           ; Gera a string "C:\path\*"

    lea rcx, [temp_path]
    mov [current_base], rcx     ; Define a base para a concatenação no loop
    lea rcx, [search_mask]
    call clean_directory_logic

    ; --- PASSO 2: Limpar C:\Windows\Temp ---
.try_windows_temp:
    lea rcx, [win_temp_path]
    mov [current_base], rcx     ; Muda a base para a pasta do sistema
    lea rcx, [win_temp_mask]    ; Máscara já hardcoded para performance
    call clean_directory_logic

.exit_proc:
    xor rcx, rcx
    call ExitProcess

; ==========================================================
; SUB-ROTINA: clean_directory_logic
; RCX = search_mask
; ==========================================================
clean_directory_logic:
    sub rsp, 40
    lea rdx, [find_data]
    call FindFirstFileA
    mov r12, rax                ; Handle de busca em R12
    cmp rax, -1
    je .done

.find_loop:
    lea rdx, [cFileName]
    lea rcx, [dot]
    call strcmp_internal
    test rax, rax
    jz .next_entry

    lea rdx, [cFileName]
    lea rcx, [dotdot]
    call strcmp_internal
    test rax, rax
    jz .next_entry

    ; Construir caminho: [current_base] + \ + cFileName
    lea rcx, [file_path]
    mov rdx, [current_base]
    call lstrcpyA

    lea rcx, [file_path]
    lea rdx, [wildcard]
    mov byte [rdx+1], 0         ; Transforma em "\"
    call lstrcatA
    mov byte [rdx+1], '*'       ; Restaura

    lea rcx, [file_path]
    lea rdx, [cFileName]
    call lstrcatA

    ; Deleção
    test dword [dwFileAttributes], 0x10
    jnz .is_dir
    lea rcx, [file_path]
    call DeleteFileA
    jmp .next_entry
.is_dir:
    lea rcx, [file_path]
    call RemoveDirectoryA

.next_entry:
    mov rcx, r12
    lea rdx, [find_data]
    call FindNextFileA
    test rax, rax
    jnz .find_loop

    mov rcx, r12
    call FindClose
.done:
    add rsp, 40
    ret

; ==========================================================
; HELPER: prepare_mask (Concatena base + \*)
; RCX = base_path, RDX = target_mask_buffer
; ==========================================================
prepare_mask:
    sub rsp, 40
    push rdx                    ; Salva target
    mov rdx, rcx                ; Source para o strcpy
    pop rcx                     ; Dest para o strcpy
    push rcx                    ; Salva dest novamente
    call lstrcpyA
    pop rcx                     ; Recupera dest
    lea rdx, [wildcard]
    call lstrcatA
    add rsp, 40
    ret

; Função de comparação de strings otimizada (Leaf Function)
strcmp_internal:
    xor rax, rax
.loop:
    mov al, [rcx]
    cmp al, [rdx]
    jne .not_equal
    test al, al
    jz .equal
    inc rcx
    inc rdx
    jmp .loop
.not_equal:
    mov rax, 1
    ret
.equal:
    xor rax, rax
    ret
