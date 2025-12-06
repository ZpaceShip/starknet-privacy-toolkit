# Dockerfile: construye la imagen con todas las dependencias dentro (sin depender del host)
FROM ubuntu:22.04

# Paquetes mínimos necesarios para que ./scripts/setup.sh funcione
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl wget git sudo ca-certificates python3.10 python3.10-dev python3-pip \
    build-essential tar gzip unzip pkg-config gnupg lsb-release \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# Copiar todo el repositorio y ejecutar setup.sh (instala Noir, bb, Scarb, Garaga)
COPY . /workspace
ENV SHELL=/bin/bash
RUN printf '\n' | bash ./scripts/setup.sh

# Defaults
EXPOSE 3000
ENTRYPOINT ["bash"]
