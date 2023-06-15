FROM --platform=$TARGETPLATFORM ruby:2.6.9-bullseye

ENV LANG=C.UTF-8

ARG TARGETPLATFORM

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ghostscript \
    libpq-dev \
    poppler-utils \
    postgresql-client \
  && rm -rf /var/lib/apt/lists/*

# On amd64 platform, we manually install libv8-node and mini_racer here first because bundler installs
# libv8-node in a wrong directory causing mini_racer installation to fail when calling 'bundle install'.
# Bundler will not attempt to reinstall mini_racer when it detects the existing installation done here.
# However, it will reinstall libv8-node to an incorrect location, which we fix later by creating a symbolic link.
# See GitHub issue: https://github.com/rubyjs/mini_racer/issues/250
RUN if [ "$TARGETPLATFORM" = "linux/amd64" ] ; then \
      gem install libv8-node -v 16.10.0.0 \
      && gem install mini_racer -v 0.6.2 ; \
    fi

# Throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock ./
RUN bundle install

# Create a symbolic link in the correct installation location of libv8-node
# pointing to the incorrect installation location.
RUN if [ "$TARGETPLATFORM" = "linux/amd64" ] ; then \
      ln -s /usr/local/bundle/gems/libv8-node-16.10.0.0-x86_64-linux/vendor/v8/x86_64-linux-musl \
        /usr/local/bundle/gems/libv8-node-16.10.0.0-x86_64-linux/vendor/v8/x86_64-linux ; \
    fi

# Copy Rubyric source code.
COPY . .
# Rails database configuration and Rubyric settings.
COPY docker/config config/
COPY docker/init_rubyric.sh /init_rubyric.sh

VOLUME /data
EXPOSE 8091

ENTRYPOINT ["/init_rubyric.sh"]
CMD ["bin/rails", "server", "-b", "0.0.0.0", "-p", "8091"]
