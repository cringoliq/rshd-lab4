#!/bin/bash
set -e

# Ждем, пока postgres инициализируется и запустится
until pg_isready -h /var/run/postgresql; do
  echo "Waiting for postgres to start..."
  sleep 1
done

echo "Postgres started, настраиваем конфиги..."

PGDATA="/var/lib/postgresql/data"

# Включаем прослушивание на всех интерфейсах
echo "listen_addresses = '*'" >> "$PGDATA/postgresql.conf"

# Добавляем нужные параметры в postgresql.conf
echo "wal_level = replica" >> "$PGDATA/postgresql.conf"
echo "max_wal_senders = 10" >> "$PGDATA/postgresql.conf"
echo "max_replication_slots = 10" >> "$PGDATA/postgresql.conf"
echo "hot_standby = on" >> "$PGDATA/postgresql.conf"
echo "synchronous_standby_names = '1 (pg_replica_b)'" >> "$PGDATA/postgresql.conf"

# Меняем pg_hba.conf — добавляем разрешение для репликации пользователя replicator
echo "host replication replicator 0.0.0.0/0 md5" >> "$PGDATA/pg_hba.conf"
echo "host all all 0.0.0.0/0 md5" >> "$PGDATA/pg_hba.conf"

# Создаем роль replicator для репликации (можно в init.sql, но так удобнее)
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
    CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'replicator';
    -- Создаем репликационные слоты для реплик
    SELECT * FROM pg_create_physical_replication_slot('pg_replica_b');
    SELECT * FROM pg_create_physical_replication_slot('pg_replica_c');
EOSQL

echo "Перезапускаем postgres для применения настроек..."

# Перезапускаем postgres (безопасно для контейнера)
pg_ctl -D "$PGDATA" -m fast restart

echo "Настройка pg-primary завершена."
