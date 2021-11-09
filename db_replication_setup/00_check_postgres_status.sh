cd /
sudo -u postgres psql -c "SELECT version();" | grep PostgreSQL | wc -l 2>/dev/null