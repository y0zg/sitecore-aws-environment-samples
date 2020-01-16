#!/usr/bin/env bash

# Expects the following environment variables to be set:
#
#   DB_HOST
#       The FQDN pointing to the SQL Server instance.
#
#   DB_USER
#       User with enough privileges to apply the DACPACs.
#       Uses SQL authentication.
#
#   DB_PASSWORD
#       Password for authenticating the above DB_USER.

SQLPACKAGE_URL="https://download.microsoft.com/download/7/5/d/75d3ba2d-2f6b-46e7-a0ef-3eaba605e935/sqlpackage-linux-x64-en-US-15.0.4573.2.zip"
SQLPACKAGE="$(pwd)/sqlpackage/sqlpackage"

curl -o sqlpackage.zip $SQLPACKAGE_URL
unzip -o sqlpackage.zip -d $(pwd)/sqlpackage
chmod +x $SQLPACKAGE

function apply() {
    local filepath=$1
    local filename=$(basename -- "$1")
    local dbname="${filename%.*}"

    echo $filename
    echo $dbname

    $(pwd)/sqlpackage/sqlpackage /a:Publish /sf:$filepath /tsn:$DB_HOST /tdn:$dbname /tu:$DB_USER /tp:"$DB_PASSWORD"
}

export -f apply

find "$(pwd)/dacpac" -type f -name '*.dacpac' -print0 | xargs -0 -I {} -P10 bash -c 'apply "{}"|tee "{}".log'

