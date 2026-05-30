#!/bin/sh
IFS='
'
export APP_CMD="$*"
exec /.AppServiceLauncher/UsagiInit /.AppServiceLauncher/UsagiInit.sh
