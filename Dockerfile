# syntax=docker/dockerfile:1

# Base image
FROM ruby:3.3.6-alpine as base

ENV BUNDLE_PATH="/usr/local/bundle"

# Build base
FROM base AS build-base
WORKDIR /app

RUN apk add --no-cache \
  git \
  bash \
  build-base \
  libxml2-dev \
  libxslt-dev \
  tzdata \
  openssl \
  postgresql-dev \
  libc6-compat && \
  bundle config --global without "${BUNDLE_WITHOUT}"  && \
  bundle config --global path "${BUNDLE_PATH}" && \
  bundle config --global deployment "${BUNDLE_DEPLOYMENT}" && \
  bundle config --global retry 5

# Build stage
FROM build-base AS build
WORKDIR /app

ENV BUNDLE_WITHOUT="development:test" \
  BUNDLE_DEPLOYMENT="1" \
  RAILS_ENV="production"

COPY ./Gemfile /app/Gemfile
COPY ./Gemfile.lock /app/Gemfile.lock  

RUN \
  bundle install && \
  find /usr/local/bundle/ \
  \( \
  -name "*.c" -o \
  -name "*.o" -o \
  -name "*.a" -o \
  -name "*.h" -o \
  -name "Makefile" -o \
  -name "*.md" \
  \) -delete && \
  chmod -R a+r "${BUNDLE_PATH}"

# Final stage
FROM base AS production
LABEL maintainer="keygen.sh <oss@keygen.sh>"

ENV BUNDLE_WITHOUT="development:test" \
  BUNDLE_DEPLOYMENT="1" \
  RAILS_ENV="production"

RUN apk add --no-cache \
  bash \
  postgresql-client \
  tzdata \
  libc6-compat && \
  adduser -h /app -g keygen -u 1000 -s /bin/bash -D keygen

COPY --from=build --chown=keygen:keygen \
  /usr/local/bundle/ /usr/local/bundle

WORKDIR /app
COPY . /app

RUN chmod +x /app/scripts/entrypoint.sh && \
  chown -R keygen:keygen /app

ENV KEYGEN_EDITION="CE" \
  KEYGEN_MODE="singleplayer" \
  RAILS_LOG_TO_STDOUT="1" \
  PORT="3000" \
  BIND="0.0.0.0"

USER keygen

ENTRYPOINT ["/app/scripts/entrypoint.sh"]
CMD ["web"]
