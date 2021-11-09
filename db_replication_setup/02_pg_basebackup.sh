export PGPASSWORD=$1
export PRIMARY_IP=$2

rm -rf /var/lib/pgsql/12/data/*
pg_basebackup -h "$PRIMARY_IP" -U replication -p 5432 --pgdata="/var/lib/pgsql/12/data/" -P -v -R -X stream -C -S secondary