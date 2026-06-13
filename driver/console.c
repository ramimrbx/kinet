#include "console.h"

#ifdef UEFI_MODE
typedef short CHAR16;
struct _EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL;
typedef long long (*EFI_TEXT_STRING)(struct _EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL *This, CHAR16 *String);
typedef struct _EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL {
    void *Reset;
    EFI_TEXT_STRING OutputString;
} EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL;

static EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL* uefi_con_out = 0;

void console_init_uefi(void* ConOut) {
    uefi_con_out = (EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL*)ConOut;
}

void console_print(const char* str) {
    if (!uefi_con_out) return;
    CHAR16 wstr[256];
    int i = 0;
    while (str[i] != '\0' && i < 250) {
        wstr[i] = (CHAR16)str[i];
        i++;
    }
    wstr[i++] = (CHAR16)'\r';
    wstr[i++] = (CHAR16)'\n';
    wstr[i] = 0;
    uefi_con_out->OutputString(uefi_con_out, wstr);
}
#else
void console_print(const char* str) {
    unsigned short* vga_buffer = (unsigned short*)0xB8000;
    // Clear screen
    for (int i = 0; i < 80 * 25; i++) {
        vga_buffer[i] = (0x0F << 8) | ' ';
    }
    // Print string at Row 2, Column 5
    int offset = (80 * 2) + 5;
    for (int i = 0; str[i] != '\0'; i++) {
        vga_buffer[offset + i] = (0x0F << 8) | str[i];
    }
}
#endif
