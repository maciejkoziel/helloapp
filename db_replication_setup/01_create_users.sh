#!/bin/bash
export PASSWORD=$1

psql -c "CREATE USER replication WITH REPLICATION ENCRYPTED PASSWORD '$PASSWORD';
        CREATE USER app WITH REPLICATION ENCRYPTED PASSWORD '$PASSWORD';"
psql -c "CREATE DATABASE helloworld;"
psql -c "GRANT ALL PRIVILEGES ON DATABASE helloworld to app;"
    