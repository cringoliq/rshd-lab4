FROM postgres:15

RUN apt-get update && \
    apt-get install -y --no-install-recommends gosu && \
    rm -rf /var/lib/apt/lists/*

# Отключаем стандартный entrypoint
ENTRYPOINT ["/bin/bash"]
CMD []