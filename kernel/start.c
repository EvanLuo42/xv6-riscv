#include "uart.h"

void 
start() 
{
    uartinit();
    uartputc_sync('a');
    while (1)
    {
        continue;
    }
}