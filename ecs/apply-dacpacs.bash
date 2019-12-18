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
DACPAC_FILES="$(pwd)/dacpac/*.dacpac"

curl -o sqlpackage.zip $SQLPACKAGE_URL
unzip -o sqlpackage.zip -d $(pwd)/sqlpackage
chmod +x $SQLPACKAGE

for filepath in $DACPAC_FILES; do

    # Use filename as database name
    # E.g. 'Sc_Web.dacpac' will be applied to database 'Sc_Web'
    filename=$(basename -- "$filepath")
    dbname="${filename%.*}"
    
    $SQLPACKAGE /a:Publish \
        /sf:$filepath \
        /tsn:$DB_HOST \
        /tdn:$dbname \
        /tu:$DB_USER \
        /tp:"$DB_PASSWORD"
done


