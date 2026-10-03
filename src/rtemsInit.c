/*
 * RTEMS configuration/initialization
 *
 * Based on code by W. Eric Norum and others
 *
 * This program may be distributed and used for any purpose.
 * I ask only that you:
 *	1. Leave this author information intact.
 *	2. Document any changes you make.
 *
 * W. Eric Norum
 * Saskatchewan Accelerator Laboratory
 * University of Saskatchewan
 * Saskatoon, Saskatchewan, CANADA
 * eric@skatter.usask.ca
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <rtems.h>
#include "rtems_config.h"

/*
** External functions
*/
void rtems_setup_shell(void);
void start_hello_task(void);
void start_monitor_task(void);

/*
** RTEMS Startup Task
*/
rtems_task Init
(
    rtems_task_argument ignored
)
{
    int status;
    printf("Hello RTEMS!\n");

    /* ----------------------------------------------------- Print RTEMS Info */
    printf("============================================================\n");

    printf( "*** RTEMS Info ***\n\n");

    printf("%s\n", rtems_get_copyright_notice() );
    printf("%s\n\n", rtems_get_version_string());

    printf("Stack size=%d\n", (int)rtems_configuration_get_stack_space_size());
    printf("Workspace size=%d\n", (int)rtems_configuration_get_work_space_size());
    printf("Ticks Per Second=%d\n",(int)rtems_clock_get_ticks_per_second());
    printf("Boot Time=%.3f\n\n", (float)rtems_clock_get_ticks_since_boot() / (float)rtems_clock_get_ticks_per_second());

    printf( "*** End RTEMS info ***\n");

    /*
    ** Create and start the HelloTask
    */
    start_hello_task();

    /*
    ** Setup the RTEMS shell and add local commands
    */
    // rtems_setup_shell();

    /*
    ** Create and start the 
    */
    // start_monitor_task();

    /*
    ** Delete the init task
    ** -- Note, the shell init does not return so the following is not called  
    */
    printf("Ending the RTEMS Init task.\n");
    status = rtems_task_delete(RTEMS_SELF);    /* should not return */
    printf("rtems_task_delete returned with status of %d.\n", status);
    exit(1);
} /* Init() */
