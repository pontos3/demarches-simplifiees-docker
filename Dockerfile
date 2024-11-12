# On part de la version de ruby utilisé par le projet sur debian.
FROM ruby:3.3.1-slim-bookworm AS builder
# FROM ruby-3.3.0-node-20.x-yarn-slim-bookworm:0.1 AS builder

# MAJ des paquets et téléchargement des dépendances nécessaire au packaging de l'application
RUN apt-get update && apt-get dist-upgrade -y && apt-get install -y \
    curl \
    git \
    gnupg \
    wget \
    build-essential \
    libcurl4 \
    libcurl4-openssl-dev \
    zlib1g-dev \
    libpq-dev \
    libicu-dev \
    unzip \
    && apt-get autoremove \
    && apt-get clean

RUN <<EOF
set -o errexit
echo "Installation de bun hors distribution linux officielle et MAJ de bun"
curl -fsSL https://bun.sh/install | bash
EOF

ENV PATH="$PATH:/root/.bun/bin/"
ENV BUN_RUNTIME_TRANSPILER_CACHE_PATH=0
ENV BUN_INSTALL_BIN=/root/.bun/bin/

# Téléchargement du code source de démarches-simplifiees dans le répertoire /ds
ARG TAG=2024-07-22-01

RUN git clone --branch $TAG --depth 1 https://github.com/demarches-simplifiees/demarches-simplifiees.fr.git ds
# Positionnement dans le répertoire de démarche simplifiée
WORKDIR /ds
#Remplacement de "api/v2" et "api/v1" par oidc afin de coller avec les points de terminaison de l'IDP.
RUN sed -i 's/api\/v2/oidc/g; s/api\/v1/oidc/g'  ./config/secrets.yml

#installation des librairies ruby par bundle
RUN bin/bundle install --deployment --jobs=4 --without='test development'

# création d'un répertoire contenant tous les fichier ".gem" exécutables ( à ajouter dans le classpath )
RUN bundle binstub puma

# install les paquets nécessaires pour l'application javascript
RUN bun install

RUN <<EOF
set -o errexit
echo "déplacement du fichier flipper.rb pour qu'il ne soit pas pris en compte dans les étapes suivantes"
mv config/initializers/flipper.rb config/initializers/flipper.disabled
cp config/env.example .env
RAILS_ENV=production bin/rails assets:precompile
RAILS_ENV=production bin/rails graphql:schema:idl
# bun run spectaql spectaql_config.yml
mv config/initializers/flipper.disabled config/initializers/flipper.disabled.rb
rm -rf node_modules log tmp spec .git vendor/bundle/ruby/*/cache specs
EOF

#COPY resources/* /ds
#RUN RAILS_ENV=production bundle exec rails assets:precompile

# CMD ["/bin/bash"]