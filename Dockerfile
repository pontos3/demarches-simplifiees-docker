# On part de la version de ruby utilisé par le projet sur debian.
FROM ruby:3.3-slim-bookworm AS builder
# FROM ruby-3.3.0-node-20.x-yarn-slim-bookworm:0.1 AS builder

# MAJ des paquets et téléchargement des dépendances nécessaire au packaging de l'application
RUN apt-get update && apt-get dist-upgrade -y && apt-get install -y \
    apt-utils \
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
ENV RAILS_ENV=production


FROM builder
# Téléchargement du code source de démarches-simplifiees dans le répertoire /diplodemarches
ARG TAG=2024-07-22-01

RUN git clone --branch $TAG --depth 1 https://github.com/demarches-simplifiees/demarches-simplifiees.fr.git diplodemarches
# Positionnement dans le répertoire de démarche simplifiée
WORKDIR /diplodemarches
#Remplacement de "api/v2" et "api/v1" par oidc afin de coller avec les points de terminaison de l'IDP.
RUN sed -i 's/api\/v2/oidc/g; s/api\/v1/oidc/g'  ./config/secrets.yml


# install les paquets nécessaires pour l'application javascript
RUN bun install --frozen-lockfile

#installation des librairies ruby par bundle
RUN gem install bundler -v 2.5.9
RUN bundle add mutex_m
RUN bundle add csv
RUN bundle config --global set deployment false
# RUN bundle config --global set frozen 1
RUN bundle config --global set frozen 0
RUN bundle config --global set without development test
RUN bundle lock --update stringio
RUN bundle install --jobs=4
RUN bundle cache

# création d'un répertoire contenant tous les fichier ".gem" exécutables ( à ajouter dans le classpath )
RUN bundle binstub puma

RUN <<EOF
set -o errexit
echo "déplacement du fichier flipper.rb pour qu'il ne soit pas pris en compte dans les étapes suivantes"
mv config/initializers/flipper.rb config/initializers/flipper.disabled
cp config/env.example .env
bundle exec rails assets:precompile --trace
bundle exec rails graphql:schema:idl --trace
# bun run spectaql spectaql_config.yml
mv config/initializers/flipper.disabled config/initializers/flipper.rb
rm -rf node_modules log tmp spec .git vendor/bundle/ruby/*/cache specs
# rm -rf node_modules log tmp spec .git specs
EOF

RUN <<EOF
set -o errexit
echo '--Start delete SMTP config--'
sed -i 's/ENV.fetch("SMTP_PORT"),/ENV.fetch("SMTP_PORT")/g' config/environments/production.rb
sed -i '/domain:               ENV.fetch("SMTP_HOST")/d' config/environments/production.rb
sed -i '/ENV.fetch("SMTP_USER")/d' config/environments/production.rb
sed -i '/ENV.fetch("SMTP_PASS")/d' config/environments/production.rb
sed -i '/ENV.fetch("SMTP_AUTHENTICATION")/d' config/environments/production.rb
sed -i '/ENV.fetch("SMTP_TLS")/d' config/environments/production.rb
sed -i '/config.force_ssl/d' config/environments/production.rb
echo '--End delete SMTP config--'
cat config/environments/production.rb
EOF

# FROM ruby:3.3.1-slim-bookworm AS runner
# ENV RAILS_ENV=production
# WORKDIR /diplodemarches
# COPY --from=builder /diplodemarches /diplodemarches
# Commenté le 13/02/2025 à 11:02
# RUN bundle config set deployment true
# RUN bundle config set --local without development test
# RUN bundle install
EXPOSE 3000
CMD ["bin/rails","server", "-p", "3000"]