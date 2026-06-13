// =====================================================================
// File: kernel/kernel.c
// Description: Core kernel entry point
// =====================================================================
#include "console.h"

void shell_main();

#ifdef UEFI_MODE
typedef struct {
    char Signature[8];
    unsigned int Revision;
    unsigned int HeaderSize;
    unsigned int CRC32;
    unsigned int Reserved;
} EFI_TABLE_HEADER;

typedef struct {
    EFI_TABLE_HEADER Hdr;
    short *FirmwareVendor;
    unsigned int FirmwareRevision;
    void *ConsoleInHandle;
    void *ConIn;
    void *ConsoleOutHandle;
    void *ConOut;
} EFI_SYSTEM_TABLE;

void kernel_main(void* ImageHandle, EFI_SYSTEM_TABLE *SystemTable) {
    if (SystemTable && SystemTable->ConOut) {
        console_init_uefi(SystemTable->ConOut);
    }
    
    // Execute userland shell
    shell_main();

    // CPU Hang loop
    while (1) {
        __asm__ volatile("hlt");
    }
}
#else
// BIOS Mode Entry
void kernel_main() {
    // Execute userland shell
    shell_main();

    // CPU Hang loop
    while (1) {
        __asm__ volatile("hlt");
    }
}
#endif
