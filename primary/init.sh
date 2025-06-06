#!/usr/bin/env bash
set -euo pipefail

PGDATA="/var/lib/postgresql/data"
SENTINEL="$PGDATA/.initialized"
[[ -f $SENTINEL ]] && { echo "❎ primary уже инициализирован"; exit 0; }

echo "🌀 initdb"
su - postgres -c "/usr/lib/postgresql/15/bin/initdb -D $PGDATA"

cat >> "$PGDATA/postgresql.conf" <<-CONF
listen_addresses            = '*'
wal_level                   = replica
max_wal_senders             = 10
max_replication_slots       = 10
hot_standby                 = on
synchronous_standby_names   = '1 (pg_replica_b)'
CONF

cat >> "$PGDATA/pg_hba.conf" <<-HBA
host replication replicator 0.0.0.0/0 md5
host all         all        0.0.0.0/0 md5
HBA

echo "🚀 временный старт Postgres"
su - postgres -c "/usr/lib/postgresql/15/bin/pg_ctl -D $PGDATA -w start"

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
  CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'replicator';
  SELECT pg_create_physical_replication_slot('pg_replica_b');
  SELECT pg_create_physical_replication_slot('pg_replica_c');
EOSQL

echo "⏹️  стоп"
su - postgres -c "/usr/lib/postgresql/15/bin/pg_ctl -D $PGDATA -m fast -w stop"

touch "$SENTINEL"
echo "✅ primary готов"
