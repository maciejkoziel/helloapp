#!/bin/bash
# update system packages
yum update -y

# enable repository to install postgresql
tee /etc/yum.repos.d/pgdg.repo<<EOF
[pgdg12]
name=PostgreSQL 12 for RHEL/CentOS 7 - x86_64
baseurl=https://download.postgresql.org/pub/repos/yum/12/redhat/rhel-7-x86_64
enabled=1
gpgcheck=0
EOF

#Update your packages index file
yum makecache

# Install PostgreSQL
yum install postgresql12 postgresql12-server -y

#Give root power to postgress for easier demo setup, bad idea for prod
echo "postgres ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

#Sudo to postgres user
sudo su - postgres

# Initialize DB
/usr/pgsql-12/bin/postgresql-12-setup initdb

# Backup PostgreSQL authentication config file
mv /var/lib/pgsql/data/pg_hba.conf /var/lib/pgsql/data/pg_hba.conf.bak

# Create our new PostgreSQL authentication config file
cat <<'EOF' > /var/lib/pgsql/12/data/pg_hba.conf
${pg_hba_file}
EOF

# Update the IPs of the address to listen from PostgreSQL config
sed -i "59i listen_addresses = '*'" /var/lib/pgsql/12/data/postgresql.conf

# Start the db service
sudo systemctl enable --now postgresql-12
sudo systemctl start postgresql-12
