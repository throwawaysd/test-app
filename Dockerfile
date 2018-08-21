#
# This is our BASE Image used for our Rails Stack.
# It will be used for all containers in all environments
# Build Sidekiq/Cron/App Containers
#
FROM phusion/passenger-ruby24:0.9.34 AS builder

RUN apt-get update -qq \
  # https://packages.debian.org/sid/gnupg2 (Digital Certificates)
  && apt-get install -y gnupg2 \
  # https://packages.debian.org/sid/libpq-dev (Postgres Headers)
  && apt-get install -y build-essential libpq-dev \
  # https://packages.debian.org/sid/tzdata (Timezone / DST Data)
  && apt-get install -y tzdata \
  # https://packages.debian.org/sid/postgresql-contrib (Postgres Contribs)
  && apt-get install -y postgresql postgresql-contrib \
  # Cleanup apt-get installs
  && apt-get clean

# Use App User
USER app

# This is an app container, setup HOME, the Working Directory and create directory for app
ENV HOME /home/app
RUN mkdir -p ${HOME}/webapp/
WORKDIR ${HOME}/webapp/

# Prepare for App Installs
RUN chown -R app:app /home/app/ && \
  gem update --system --no-document && \
  gem install bundler

USER root

# Enable Nginx and Passenger
RUN rm -f /etc/service/nginx/down && \
    rm /etc/nginx/sites-available/default && \
    rm /etc/nginx/sites-enabled/default

# Important! Combine install commands with cleanup so tmp files are removed from the layer
RUN apt-get update -qq \
  && apt-get install -qq imagemagick libmagick++-dev libmagic-dev \
  && apt-get clean

# Copy Gemfile for Install
COPY --chown=app:app Gemfile Gemfile.lock ${HOME}/webapp/

# Install Dependencies
RUN bundle install --quiet --jobs=4 --retry 15

# Configure App Dir
COPY --chown=app:app . ${HOME}/webapp/

# Copy and update ownership for application configurations
RUN cp config/docker/webapp.conf      /etc/nginx/sites-enabled/webapp.conf && \
    cp config/docker/nginx.conf       /etc/nginx/nginx.conf && \
    cp config/docker/env.conf         /etc/nginx/main.d/env.conf && \
    cp config/docker/passenger.conf   /etc/nginx/conf.d/passenger.conf && \
    chown -R app:app /home/app/

# Forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
	&& ln -sf /dev/stderr /var/log/nginx/error.log \
  && ln -sf /dev/stdout /home/app/webapp/log/main.log

# Feels weird to run this as root?
# We may want to run this as APP
USER root

EXPOSE 80

# Use baseimage-docker's init process.
CMD ["/sbin/my_init"]
