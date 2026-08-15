FROM ubuntu:24.04

RUN apt-get update && \
    apt-get install -y curl unzip && \
    rm -rf /var/lib/apt/lists/*

RUN curl -L \
    https://github.com/flamewing/asl-releases/releases/download/snapshot-snapshot-v1.4.2.20250717/asl-ubuntu-x86_64-v1.4.2.20250717.zip \
    -o /tmp/asl.zip && \
    mkdir -p /opt/asl && \
    unzip /tmp/asl.zip -d /opt/asl && \
    rm /tmp/asl.zip

WORKDIR /sce

CMD ["bash", "-c", "./build-linux-docker.sh"]
