#!/bin/bash
set -e

PGDATA="/var/lib/postgresql/data"
POSTGRES_USER=${POSTGRES_USER:-postgres}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-postgres}

# Проверка: запущен ли PostgreSQL?
function is_postgres_running {
  su - postgres -c "/usr/lib/postgresql/15/bin/pg_ctl -D $PGDATA status" > /dev/null 2>&1
}

if [ ! -s "$PGDATA/PG_VERSION" ]; then
  echo "🧪 Инициализация кластера..."
  su - postgres -c "/usr/lib/postgresql/15/bin/initdb -D $PGDATA"

  echo "✅ Разрешаем временные доверенные подключения..."
  echo "host all all 0.0.0.0/0 trust" >> "$PGDATA/pg_hba.conf"
  echo "host replication replicator 0.0.0.0/0 trust" >> "$PGDATA/pg_hba.conf"

  su - postgres -c "/usr/lib/postgresql/15/bin/pg_ctl -D $PGDATA -o \"-c listen_addresses='*'\" -w start"

  echo "🔐 Установка пароля пользователю $POSTGRES_USER..."
  echo "ALTER USER $POSTGRES_USER WITH PASSWORD '$POSTGRES_PASSWORD';" | psql -U "$POSTGRES_USER"

  echo "👤 Создание роли replicator и слота pg_replica_b..."
  psql -U "$POSTGRES_USER" <<-EOSQL
    DO \$\$ BEGIN
      IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'replicator') THEN
        CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'replicator';
      END IF;
    END \$\$;
    SELECT * FROM pg_create_physical_replication_slot('pg_replica_b');
EOSQL

  echo "🔒 Возвращаем md5-аутентификацию..."
  sed -i "s/^host all all 0.0.0.0\/0 trust/host all all 0.0.0.0\/0 md5/" "$PGDATA/pg_hba.conf"
  sed -i "s/^host replication replicator 0.0.0.0\/0 trust/host replication replicator 0.0.0.0\/0 md5/" "$PGDATA/pg_hba.conf"

  echo "🔁 Перезапуск PostgreSQL для применения pg_hba.conf..."
  echo "synchronous_standby_names = 'pg_replica_b'" >> "$PGDATA/postgresql.conf"
  echo "synchronous_commit = on" >> "$PGDATA/postgresql.conf"

  su - postgres -c "/usr/lib/postgresql/15/bin/pg_ctl -D $PGDATA -m fast restart"
else
  echo "📦 Кластер уже инициализирован."

  if ! is_postgres_running; then
    echo "🚀 Запуск PostgreSQL..."
    su - postgres -c "/usr/lib/postgresql/15/bin/pg_ctl -D $PGDATA -o \"-c listen_addresses='*'\" -w start"
  else
    echo "✅ PostgreSQL уже работает."
  fi
fi

echo "📋 Повторная проверка роли и слота..."
PGPASSWORD="$POSTGRES_PASSWORD" psql -U "$POSTGRES_USER" <<-EOSQL
  DO \$\$ BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'replicator') THEN
      CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'replicator';
    END IF;
  END \$\$;

  DO \$\$ BEGIN
    IF NOT EXISTS (SELECT * FROM pg_replication_slots WHERE slot_name = 'pg_replica_b') THEN
      PERFORM pg_create_physical_replication_slot('pg_replica_b');
    END IF;
  END \$\$;
EOSQL

echo "✅ Настройка завершена."

exec tail -f /dev/null
