#!/usr/bin/env bash
set -euo pipefail

SENTINEL="$PGDATA/.initialized"
[[ -f $SENTINEL ]] && { echo "❎ replica уже инициализирована"; exit 0; }

# ждём primary
until pg_isready -h "$REPL_UPSTREAM_HOST" -U replicator; do
  echo "⌛  ждём $REPL_UPSTREAM_HOST"
  sleep 2
done

# slot
slot_exists=$(psql -h "$REPL_UPSTREAM_HOST" -U replicator -d postgres -tAc \
  "SELECT 1 FROM pg_replication_slots WHERE slot_name = '$NODE_NAME'")
if [[ "$slot_exists" != "1" ]]; then
  echo "➕ создаём slot $NODE_NAME"
  psql -h "$REPL_UPSTREAM_HOST" -U replicator -d postgres \
      -c "SELECT pg_create_physical_replication_slot('$NODE_NAME')"
fi

echo "🌀 pg_basebackup"
pg_basebackup -h "$REPL_UPSTREAM_HOST" -U replicator \
              -D "$PGDATA" -Fp -Xs -P -R

cat >> "$PGDATA/postgresql.conf" <<-CONF
primary_slot_name = '$NODE_NAME'
hot_standby       = on
CONF

echo "primary_conninfo = 'host=$REPL_UPSTREAM_HOST port=5432 user=replicator password=replicator application_name=$NODE_NAME'" \
  >> "$PGDATA/postgresql.auto.conf"

touch "$SENTINEL"
echo "✅ replica $NODE_NAME готова"
