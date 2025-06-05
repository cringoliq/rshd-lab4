FROM postgres:16

RUN apt-get update && apt-get install -y gosu && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh
RUN chmod 700 "$PGDATA"
RUN chown -R postgres:postgres "$PGDATA"
ENTRYPOINT ["/entrypoint.sh"]
