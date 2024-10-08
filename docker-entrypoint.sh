#!/bin/bash

CARBONE_USE_S3_PLUGIN=${CARBONE_USE_S3_PLUGIN:-true}

CONTAINER_ALREADY_STARTED="CONTAINER_ALREADY_STARTED_PLACEHOLDER"
if [ ! -e $CONTAINER_ALREADY_STARTED ]; then
    touch $CONTAINER_ALREADY_STARTED
    if [ "$CARBONE_USE_AZURE_PLUGIN" = true ]; then
        echo "Configuring Carbone with Azure plugin"
        cp -r /app/plugin-azure/node_modules /app/plugin/
        cp -r /app/plugin-azure/*.js /app/plugin/
    elif [ "$CARBONE_USE_S3_PLUGIN" = true ]; then
        echo "Configuring Carbone with S3 plugin"
        cp -r /app/plugin-s3/node_modules /app/plugin/
        cp -r /app/plugin-s3/*.js /app/plugin/
    fi
fi

exec ./carbone-ee-linux $@