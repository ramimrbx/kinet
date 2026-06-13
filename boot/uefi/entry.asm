; =====================================================================
; File: boot/uefi/boot.asm
; Description: Unified UEFI Bootloader supporting x86 and x86_64
; =====================================================================
extern kernel_main

section .text

%ifdef ARCH_X86_64
    ; ==================== x86_64 (64-bit) UEFI Entry ====================
    [bits 64]
    global efi_main

    efi_main:
        ; Microsoft x64 calling convention:
        ; RCX = ImageHandle
        ; RDX = SystemTable
        sub rsp, 40                  ; Allocate shadow space + stack alignment
        call kernel_main
        add rsp, 40
        ret

%else
    ; ==================== x86 (32-bit) UEFI Entry ====================
    [bits 32]
    global efi_main

    efi_main:
        ; IA32 UEFI calling convention is standard cdecl.
        ; Parameters on stack:
        ; [esp + 4] = ImageHandle
        ; [esp + 8] = SystemTable
        mov eax, [esp + 4]
        mov edx, [esp + 8]
        
        push edx                     ; Push SystemTable
        push eax                     ; Push ImageHandle
        call kernel_main
        add esp, 8
        ret
%endif
