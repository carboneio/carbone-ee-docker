#!/bin/bash

CARBONE_USE_S3_PLUGIN=${CARBONE_USE_S3_PLUGIN:-true}

CARBONE_EE_WORKDIR=${CARBONE_EE_WORKDIR:-/app}

CONTAINER_ALREADY_STARTED="CONTAINER_ALREADY_STARTED_PLACEHOLDER"
if [ ! -e $CONTAINER_ALREADY_STARTED ]; then
    touch $CONTAINER_ALREADY_STARTED
    if [ "$CARBONE_USE_AZURE_PLUGIN" = true ]; then
        echo "Configuring Carbone with Azure plugin"
        cp -r ${CARBONE_EE_WORKDIR}/plugin-azure/node_modules ${CARBONE_EE_WORKDIR}/plugin/
        cp -r ${CARBONE_EE_WORKDIR}/plugin-azure/*.js ${CARBONE_EE_WORKDIR}/plugin/
    elif [ "$CARBONE_USE_S3_PLUGIN" = true ]; then
        echo "Configuring Carbone with S3 plugin"
        cp -r ${CARBONE_EE_WORKDIR}/plugin-s3/node_modules ${CARBONE_EE_WORKDIR}/plugin/
        cp -r ${CARBONE_EE_WORKDIR}/plugin-s3/*.js ${CARBONE_EE_WORKDIR}/plugin/
    fi
fi

## Set public key (for V5 compatibility)
if [ -n "$CARBONE_AUTHENTICATION_PUBLIC_KEY" ]; then
    mkdir ${CARBONE_EE_WORKDIR}/config
    echo -e $CARBONE_AUTHENTICATION_PUBLIC_KEY > ${CARBONE_EE_WORKDIR}/config/key.pub
fi

exec ./carbone-ee-linux $@
