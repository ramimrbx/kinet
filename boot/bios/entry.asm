; =====================================================================
; File: boot/bios/boot.asm
; Description: Unified BIOS Bootloader supporting x86 and x86_64
;              Compatible with FAT12 filesystem layout
; =====================================================================
[bits 16]
[org 0x7c00]

; Jump over the FAT12 BPB
jmp short start
nop

; =====================================================================
; FAT12 BIOS Parameter Block (BPB)
; =====================================================================
db "MSWIN4.1"          ; OEM Name (8 bytes)
dw 512                  ; Bytes per sector
db 1                    ; Sectors per cluster
dw 1                    ; Reserved sectors (this boot sector)
db 2                    ; Number of FATs
dw 224                  ; Root directory entries
dw 2880                 ; Total sectors (1.44MB)
db 0xf0                 ; Media descriptor
dw 9                    ; Sectors per FAT
dw 18                   ; Sectors per track
dw 2                    ; Number of heads
dd 0                    ; Hidden sectors
dd 0                    ; Large sectors
db 0                    ; Drive number
db 0                    ; Reserved
db 0x29                 ; Extended boot signature
dd 0x12345678           ; Volume ID
db "KINET OS   "        ; Volume label (11 bytes)
db "FAT12   "           ; File system type (8 bytes)

; =====================================================================
; Bootloader Code
; =====================================================================
KERNEL_OFFSET equ 0x9000

start:
    cli                      ; Clear interrupts
    xor ax, ax               ; Initialize segment registers to 0
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov bp, 0x9000           ; Setup stack base pointer
    mov sp, bp               ; Setup stack pointer
    sti                      ; Restore interrupts

    mov [BOOT_DRIVE], dl     ; BIOS stores boot drive id in DL register

    ; Load the kernel starting from LBA 33 (first cluster of data region in FAT12)
    ; We read 15 sectors (7.5KB) which is plenty for our small kernel
    mov ax, 33               ; AX = Starting LBA (Sector 33)
    mov cx, 15               ; CX = Number of sectors to read
    mov bx, KERNEL_OFFSET    ; ES:BX = Destination address
    call load_kernel_lba

    ; Transition to protected/long mode according to the target architecture
    cli

%ifdef ARCH_X86_64
    ; ==================== x86_64 Long Mode Transition ====================
    ; 1. Clear memory for 4-Level Page Tables starting at 0x1000
    mov edi, 0x1000
    xor eax, eax
    mov ecx, 4096            ; Clear 16KB of memory
    rep stosd

    ; 2. Setup Page Table Structures for Identity Mapping (First 2MB)
    mov dword [0x1000], 0x2003     ; PML4[0] points to PDPT at 0x2000 (Present + Writable)
    mov dword [0x2000], 0x3003     ; PDPT[0] points to PD at 0x3000   (Present + Writable)
    mov dword [0x3000], 0x4003     ; PD[0] points to PT at 0x4000     (Present + Writable)

    ; Map 512 entries in Page Table (PT) -> 512 * 4KB = 2MB mapped area
    mov edi, 0x4000
    mov eax, 0x00000003            ; Physical address 0 + flags (Present + Writable)
    mov ecx, 512
.set_pt_entries:
    mov [edi], eax
    mov dword [edi+4], 0           ; Upper 32-bits set to 0
    add edi, 8
    add eax, 4096                  ; Move to next 4KB physical page
    loop .set_pt_entries

    ; 3. Enable PAE (Physical Address Extension) in CR4
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax

    ; 4. Load PML4 address into CR3
    mov eax, 0x1000
    mov cr3, eax

    ; 5. Enable Long Mode in EFER MSR
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8
    wrmsr

    ; 6. Enable Paging and Protected Mode simultaneously in CR0
    mov eax, cr0
    or eax, (1 << 31) | (1 << 0)
    mov cr0, eax

    ; 7. Load 64-bit Global Descriptor Table (GDT)
    lgdt [gdt64_pointer]

    ; 8. Make a far jump into the 64-bit Code Segment
    db 0x66, 0xEA
    dd init_64bit
    dw CODE64_SEG

%else
    ; ==================== x86 Protected Mode Transition ====================
    ; Load 32-bit GDT and enable PE bit in CR0
    lgdt [gdt32_descriptor]
    mov eax, cr0
    or eax, 0x1
    mov cr0, eax
    jmp CODE32_SEG:init_32bit
%endif

; =====================================================================
; Load sectors from disk using LBA addressing (CHS conversion loop)
; =====================================================================
load_kernel_lba:
.read_sector:
    push ax
    push cx
    push bx

    ; Convert LBA in AX to CHS:
    ; Sector = (LBA % 18) + 1
    ; Head = (LBA / 18) % 2
    ; Cylinder = LBA / (18 * 2)
    xor dx, dx
    mov cx, 18
    div cx                   ; AX = LBA / 18, DX = LBA % 18
    inc dx                   ; DX = Sector index (1-based)
    mov cl, dl               ; CL = Sector index

    mov dx, ax               ; DX = LBA / 18
    and dl, 1                ; DL = Head (0 or 1)
    mov dh, dl               ; DH = Head

    shr ax, 1                ; AX = Cylinder = (LBA / 18) / 2
    mov ch, al               ; CH = Cylinder

    mov dl, [BOOT_DRIVE]     ; DL = Boot drive
    mov ax, 0x0201           ; AH = 2 (read), AL = 1 (1 sector)
    int 0x13                 ; BIOS disk read interrupt
    jc disk_error            ; Halt on error

    pop bx
    pop cx
    pop ax

    inc ax                   ; Next LBA sector
    add bx, 512              ; Increment memory offset
    loop .read_sector
    ret

disk_error:
    jmp $                    ; Halt on disk read error

; =====================================================================
; 32-bit Protected Mode Startup (x86)
; =====================================================================
[bits 32]
%ifndef ARCH_X86_64
init_32bit:
    mov ax, DATA32_SEG
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov ebp, 0x90000
    mov esp, ebp

    jmp KERNEL_OFFSET
%endif

; =====================================================================
; 64-bit Long Mode Startup (x86_64)
; =====================================================================
%ifdef ARCH_X86_64
init_64bit:
    mov ax, DATA64_SEG
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    jmp KERNEL_OFFSET
%endif

; =====================================================================
; Descriptors and segment info
; =====================================================================
BOOT_DRIVE db 0

%ifdef ARCH_X86_64
; 64-bit Global Descriptor Table
gdt64_start:
    dq 0x0000000000000000          ; Null Descriptor
gdt64_code:
    dq (1<<43) | (1<<44) | (1<<47) | (1<<53) ; Code segment
gdt64_data:
    dq (1<<41) | (1<<44) | (1<<47)           ; Data segment
gdt64_end:

gdt64_pointer:
    dw gdt64_end - gdt64_start - 1
    dq gdt64_start

CODE64_SEG equ gdt64_code - gdt64_start
DATA64_SEG equ gdt64_data - gdt64_start

%else
; 32-bit Global Descriptor Table
gdt32_start:
    dd 0x0
    dd 0x0
gdt32_code:
    dw 0xffff
    dw 0x0
    db 0x0
    db 10011010b
    db 11001111b
    db 0x0
gdt32_data:
    dw 0xffff
    dw 0x0
    db 0x0
    db 10010010b
    db 11001111b
    db 0x0
gdt32_end:

gdt32_descriptor:
    dw gdt32_end - gdt32_start - 1
    dd gdt32_start

CODE32_SEG equ gdt32_code - gdt32_start
DATA32_SEG equ gdt32_data - gdt32_start
%endif

; Boot sector padding and magic signature
times 510-($-$$) db 0
dw 0xaa55
