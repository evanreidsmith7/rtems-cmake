#include <stdio.h>
#include <rtems.h>
#include <rtems/shell.h>

void rtems_setup_shell(void)
{
    rtems_status_code sc;

    printf("[rtems] Starting RTEMS shell on /dev/console\n");

    sc = rtems_shell_init(
        "SHLL",                    /* task name        */
        4 * RTEMS_MINIMUM_STACK_SIZE, /* stack size       */
        100,                        /* task priority    */
        "/dev/console",            /* device           */
        true,                       /* forever (relogin)*/
        false,                      /* do not wait here */
        NULL                        /* no login check   */
    );

    if (sc != RTEMS_SUCCESSFUL) {
        printf("[rtems] rtems_shell_init failed: %d\n", sc);
    }

    return;
}
