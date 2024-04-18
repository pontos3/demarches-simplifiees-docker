# On part de la version de ruby utilisé par le projet sur debian.
FROM ruby:3.3.0-slim-bookworm as builder

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
    && apt-get autoremove \
    && apt-get clean

# Téléchargement du code source de démarches-simplifiees dans le répertoire /ds
ARG TAG=2024-02-14-01
RUN git clone --branch $TAG --depth 1 https://github.com/demarches-simplifiees/demarches-simplifiees.fr.git ds
WORKDIR /ds

#
RUN bundle install
RUN RAILS_ENV=production bundle exec rails assets:precompile

CMD ["/bin/bash"]