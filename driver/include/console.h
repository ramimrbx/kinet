#ifndef CONSOLE_H
#define CONSOLE_H

#ifdef __cplusplus
extern "C" {
#endif

void console_init_uefi(void* ConOut);
void console_print(const char* str);

#ifdef __cplusplus
}
#endif

#endif
