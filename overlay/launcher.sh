#!/bin/sh
APP_CMD=$(printf '%q ' "$@")
export APP_CMD
exec /.AppServiceLauncher/UsagiInit /.AppServiceLauncher/UsagiInit.sh
