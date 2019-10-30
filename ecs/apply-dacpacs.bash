#!/usr/bin/env bash

SQLPACKAGE="$(pwd)/sqlpackage/sqlpackage"
DACPAC_FILES="$(pwd)/dacpac/*.dacpac"

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


