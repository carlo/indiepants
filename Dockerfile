FROM phusion/passenger-ruby22:0.9.15
MAINTAINER Hendrik Mans "hendrik@mans.de"

# Set correct environment variables.
ENV HOME /root

# Use baseimage-docker's init process.
CMD ["/sbin/my_init"]

# Yes, we want nginx and passenger.
RUN rm -f /etc/service/nginx/down /etc/nginx/sites-enabled/default
ADD config/nginx.conf /etc/nginx/sites-enabled/indiepants.conf

# Run Bundler in a cache-efficient way
WORKDIR /tmp
ADD Gemfile /tmp/
ADD Gemfile.lock /tmp/
RUN bundle install --jobs=3 --retry=3

# Install IndiePants code
RUN mkdir /home/app/indiepants
ADD . /home/app/indiepants
RUN chown -R app:app /home/app/indiepants


# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
