; =====================================================================
; File: arch/boot/x86/boot.asm
; Description: x86 architecture boot entry dispatcher
; =====================================================================
%define ARCH_X86

%ifdef BIOS
    %include "boot/bios/entry.asm"
%endif

%ifdef UEFI
    %include "boot/uefi/entry.asm"
%endif
