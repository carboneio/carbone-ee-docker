#!/bin/bash

CARBONE_USE_S3_PLUGIN=${CARBONE_USE_S3_PLUGIN:-true}

CARBONE_EE_WORKDIR=${CARBONE_EE_WORKDIR:-/app}
if [ $CARBONE_EE_WORKDIR != "/app" ]; then
    mkdir ${CARBONE_EE_WORKDIR}
fi

CONTAINER_ALREADY_STARTED="CONTAINER_ALREADY_STARTED_PLACEHOLDER"
if [ ! -e $CONTAINER_ALREADY_STARTED ]; then
    touch $CONTAINER_ALREADY_STARTED
    if [ "$CARBONE_USE_AZURE_PLUGIN" = true ]; then
        echo "Configuring Carbone with Azure plugin"
        cp -r /app/plugin-azure/node_modules ${CARBONE_EE_WORKDIR}/plugin/
        cp -r /app/plugin-azure/*.js ${CARBONE_EE_WORKDIR}/plugin/
    elif [ "$CARBONE_USE_S3_PLUGIN" = true ]; then
        echo "Configuring Carbone with S3 plugin"
        cp -r /app/plugin-s3/node_modules ${CARBONE_EE_WORKDIR}/plugin/
        cp -r /app/plugin-s3/*.js ${CARBONE_EE_WORKDIR}/plugin/
    fi
fi

## For Chrome execution, we need first to test if sys_admin cap is enabled
## if disable, we force no-sandbox mode
SYS_ADMIN=`setpriv -d | grep sys_admin`
if [ "$SYS_ADMIN" = "" ]; then
    CARBONE_CHROME_FLAGS="--no-sandbox"
    echo "Running Chrome without sandbox"
else
    echo "Running Chrome with sandbox"
fi

exec ./carbone-ee-linux $@
