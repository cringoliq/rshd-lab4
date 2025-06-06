#!/bin/bash
set -e


PGDATA="/var/lib/postgresql/data"

if [ ! -s "$PGDATA/PG_VERSION" ]; then
  echo "Инициализация базы данных..."
  su - postgres -c "/usr/lib/postgresql/15/bin/initdb -D $PGDATA"    
fi

echo "Запуск PostgreSQL..."
su - postgres -c "/usr/lib/postgresql/15/bin/pg_ctl -D $PGDATA -o \"-c listen_addresses='*'\" -w start"

echo "Postgres запущен, настраиваем конфиги..."

# Настройки postgresql.conf
echo "listen_addresses = '*'" >> "$PGDATA/postgresql.conf"
echo "wal_level = replica" >> "$PGDATA/postgresql.conf"
echo "max_wal_senders = 10" >> "$PGDATA/postgresql.conf"
echo "max_replication_slots = 10" >> "$PGDATA/postgresql.conf"
echo "hot_standby = on" >> "$PGDATA/postgresql.conf"
echo "synchronous_standby_names = '1 (pg_replica_b)'" >> "$PGDATA/postgresql.conf"

# pg_hba.conf для доступа и репликации
echo "host replication replicator 0.0.0.0/0 md5" >> "$PGDATA/pg_hba.conf"
echo "host all all 0.0.0.0/0 md5" >> "$PGDATA/pg_hba.conf"

# Создание роли replicator и слотов
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
    CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'replicator';
    SELECT * FROM pg_create_physical_replication_slot('pg_replica_b');
    SELECT * FROM pg_create_physical_replication_slot('pg_replica_c');
EOSQL

echo "Перезапускаем PostgreSQL с новыми настройками..."
su - postgres -c "/usr/lib/postgresql/15/bin/pg_ctl -D "$PGDATA" -m fast restart"

echo "✅ Настройка pg-primary завершена и сервер работает."

# Оставляем процесс PostgreSQL запущенным в переднем плане
# чтобы контейнер "жил" — иначе Docker его остановит
exec tail -f /dev/null
