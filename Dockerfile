# syntax=docker/dockerfile:1
# check=error=true

# This Dockerfile is designed for production, not development. Use with Kamal or build'n'run by hand:
# docker build -t memori .
# docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value from config/master.key> --name memori memori

# For a containerized dev environment, see Dev Containers: https://guides.rubyonrails.org/getting_started_with_devcontainer.html

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=3.3.10
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Try setup Python virtual environment


# Rails app lives here
WORKDIR /rails

# Install base packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libvips postgresql-client ffmpeg libjpeg62-turbo-dev libyaml-0-2 && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/* /var/tmp/*

# Set production environment
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test"

# Throw-away build stage to reduce size of final image
FROM base AS build

# Install packages needed to build gems
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev pkg-config libyaml-dev && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/* /var/tmp/*

# Install application gems
COPY Gemfile Gemfile.lock fat_free_crm.gemspec ./
COPY lib/fat_free_crm/version.rb lib/fat_free_crm/version.rb
RUN bundle install --no-cache --jobs 4 --retry 3 && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

# Copy application code
COPY . .

# Precompile bootsnap code and assets
RUN bundle exec bootsnap precompile --gemfile app/ lib/ && \
    SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile && \
    rm -rf tmp/cache vendor/bundle test spec

# Final stage for app image
FROM base

# Copy built artifacts: gems, application
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Remove unnecessary files
RUN rm -rf /rails/.git /rails/tmp/* /rails/log/* && \
    mkdir -p /rails/tmp/pids

# Setup runtime user and permissions
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails db log  tmp public/assets app/assets && \
    chmod -R u+w db log tmp public/assets app/assets


# RUN apt-get update -qq && apt-get install --no-install-recommends -y python3 python3-pip python3.11-venv
# RUN /rails/python_scripts/setup_venv.sh


USER 1000:1000

# Entrypoint prepares the database
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start the Rails server
EXPOSE 3000 80 8088 8080
CMD ["./bin/rails", "server", "-b", "0.0.0.0"]
