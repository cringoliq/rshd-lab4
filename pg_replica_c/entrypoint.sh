#!/bin/bash
set -e

PGDATA="/var/lib/postgresql/data"
REPL_USER="replicator"
REPL_DB="postgres"



echo "Ждем доступности upstream $REPL_UPSTREAM_HOST..."
until pg_isready -h "$REPL_UPSTREAM_HOST" -U "$REPL_USER"; do
  sleep 2
done

echo "Проверяем replication slot '$NODE_NAME' на $REPL_UPSTREAM_HOST..."
slot_exists=$(PGPASSWORD="$REPL_UPSTREAM_PASSWORD" psql -h "$REPL_UPSTREAM_HOST" -U "$REPL_USER" -d "$REPL_DB" -tAc "SELECT 1 FROM pg_replication_slots WHERE slot_name = '$NODE_NAME';")

if [ "$slot_exists" != "1" ]; then
  echo "Создаём replication slot '$NODE_NAME'..."
  PGPASSWORD="$REPL_UPSTREAM_PASSWORD" psql -h "$REPL_UPSTREAM_HOST" -U "$REPL_USER" -d "$REPL_DB" -c "SELECT pg_create_physical_replication_slot('$NODE_NAME');"
else
  echo "Replication slot '$NODE_NAME' уже существует."
fi

if [ ! -s "$PGDATA/PG_VERSION" ]; then
  echo "Выполняем pg_basebackup с $REPL_UPSTREAM_HOST..."
  pg_basebackup -h "$REPL_UPSTREAM_HOST" -U "$REPL_USER" -D "$PGDATA" -Fp -Xs -P -R

  echo "primary_slot_name = '$NODE_NAME'" >> "$PGDATA/postgresql.conf"
  echo "hot_standby = on" >> "$PGDATA/postgresql.conf"

  echo "Установка primary_conninfo..."
  echo "primary_conninfo = 'host=$REPL_UPSTREAM_HOST port=5432 user=$REPL_USER password=$REPL_UPSTREAM_PASSWORD application_name=$NODE_NAME'" >> "$PGDATA/postgresql.auto.conf"
else
  echo "Каталог $PGDATA уже инициализирован."
fi

# Исправляем владельца и права на каталог данных
echo "Проверяем права на каталог данных..."
chown -R postgres:postgres "$PGDATA"
chmod 700 "$PGDATA"

echo "Настройка завершена"
su - postgres -c "/usr/lib/postgresql/15/bin/pg_ctl -D $PGDATA -o \"-c listen_addresses='*'\" -w start"

