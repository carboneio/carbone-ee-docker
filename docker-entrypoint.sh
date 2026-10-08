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

## Start Chrome once with its sandbox enabled and wait for DevTools to come up.
## Chrome needs to create an unprivileged user namespace: depending on the kernel,
## seccomp and AppArmor settings this may be allowed or not, whatever the capabilities.
chrome_sandbox_available() {
    local log=$(mktemp) profile=$(mktemp -d) ready=1
    "$CARBONE_EE_CHROMEPATH" --headless --remote-debugging-port=0 --user-data-dir="$profile" about:blank >"$log" 2>&1 &
    local pid=$!
    for i in $(seq 1 50); do
        if grep -q "DevTools listening" "$log"; then ready=0; break; fi
        kill -0 $pid 2>/dev/null || break
        sleep 0.1
    done
    kill $pid 2>/dev/null
    wait $pid 2>/dev/null
    rm -rf "$log" "$profile"
    return $ready
}

if [ "$CARBONE_DISABLE_CHROME" = true ]; then
    echo "Chromium converter is disabled"
    unset CARBONE_EE_CHROMEPATH
elif [ -z "$CARBONE_EE_CHROMEPATH" ]; then
    : # No Chrome in this image variant
elif [ -n "$CARBONE_CHROME_FLAGS" ]; then
    echo "Running Chrome with user-provided flags: $CARBONE_CHROME_FLAGS"
elif chrome_sandbox_available 2>/dev/null; then
    echo "Running Chrome with sandbox"
else
    export CARBONE_CHROME_FLAGS="--no-sandbox"
    echo "WARNING: Running Chrome without sandbox, the container does not allow unprivileged user namespaces."
    echo "WARNING: To enable the sandbox, allow user namespaces in the seccomp profile (or add the SYS_ADMIN capability)."
    echo "WARNING: If you do not need HTML to PDF conversion, set CARBONE_DISABLE_CHROME=true or use the no-chrome image."
fi

exec ./carbone-ee-linux $@
