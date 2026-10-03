#include <stdio.h>
#include <rtems.h>
#include <stdlib.h>

/*
 * Simple RTEMS task that periodically prints "Hello from RTEMS task!".
 */

rtems_task HelloTask(
    rtems_task_argument arg
)
{
    rtems_interval ticks_per_second = rtems_clock_get_ticks_per_second();
    int i = 0;

    while (i < 10)
    {
        printf("\n~ Hello ~\n");
        rtems_task_wake_after(ticks_per_second);
        i++;
    }

    rtems_task_delete(RTEMS_SELF);
    exit(1);
}

/*
 * Helper function to create and start the HelloTask.
 */
void start_hello_task(void)
{
    rtems_id          task_id;
    rtems_status_code sc;

    sc = rtems_task_create(
        rtems_build_name('H', 'E', 'L', 'O'),
        122,                           /* priority (lower than Init's 120) */
        RTEMS_MINIMUM_STACK_SIZE,
        RTEMS_DEFAULT_MODES,
        RTEMS_DEFAULT_ATTRIBUTES,
        &task_id
    );

    if (sc != RTEMS_SUCCESSFUL) {
        printf("HelloTask create failed: %d\n", sc);
        return;
    }

    sc = rtems_task_start(task_id, HelloTask, 0);
    if (sc != RTEMS_SUCCESSFUL) {
        printf("HelloTask start failed: %d\n", sc);
    }
}
