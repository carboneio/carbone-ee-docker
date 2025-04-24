#!/bin/bash

## For Chrome execution, we need first to test if sys_admin cap is enabled
setpriv -d | grep sys_admin > /dev/null || unset CARBONE_EE_CHROMEPATH

if [ -z "$CARBONE_EE_CHROMEPATH" ]; then
    echo "---------- CHROME SUPPORT IS DISABLED -----------"
    echo "Running Chrome in a Docker container requires"
    echo "SYS_ADMIN capabilities. "
    echo "To enable it, use the --cap-add SYS_ADMIN option."
    echo "-------------------------------------------------"
fi

exec ./carbone-ee-linux $@