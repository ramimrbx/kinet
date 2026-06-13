; =====================================================================
; File: arch/boot/x86_64/boot.asm
; Description: x86_64 architecture boot entry dispatcher
; =====================================================================
%define ARCH_X86_64

%ifdef BIOS
    %include "boot/bios/entry.asm"
%endif

%ifdef UEFI
    %include "boot/uefi/entry.asm"
%endif
