FROM postgres:16

RUN apt-get update && \
    apt-get install -y --no-install-recommends gosu && \
    rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /opt/init/replica.sh
RUN chmod +x /opt/init/replica.sh

CMD ["sleep", "infinity"]
