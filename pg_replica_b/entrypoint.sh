#!/bin/bash
set -e

if [ "$(id -u)" = '0' ]; then
  exec gosu postgres "$0" "$@"
fi

until pg_isready -h "$REPL_UPSTREAM_HOST" -U replicator; do
  echo "Ждем доступности $REPL_UPSTREAM_HOST..."
  sleep 2
done

echo "Проверяем наличие replication slot '$NODE_NAME' на $REPL_UPSTREAM_HOST..."
slot_exists=$(psql -h "$REPL_UPSTREAM_HOST" -U replicator -d postgres -tAc "SELECT 1 FROM pg_replication_slots WHERE slot_name = '$NODE_NAME'")
if [ "$slot_exists" != "1" ]; then
  echo "Создаем replication slot '$NODE_NAME' на $REPL_UPSTREAM_HOST"
  psql -h "$REPL_UPSTREAM_HOST" -U replicator -d postgres -c "SELECT pg_create_physical_replication_slot('$NODE_NAME')"
else
  echo "Replication slot '$NODE_NAME' уже существует."
fi

if [ ! -s "$PGDATA/PG_VERSION" ]; then
  echo "🌀 Выполняется pg_basebackup с $REPL_UPSTREAM_HOST"
  pg_basebackup -h "$REPL_UPSTREAM_HOST" -U replicator -D "$PGDATA" -Fp -Xs -P -R

  echo "primary_slot_name = '$NODE_NAME'" >> "$PGDATA/postgresql.conf"
  echo "hot_standby = on" >> "$PGDATA/postgresql.conf"
fi

exec postgres -D "$PGDATA"
