FROM ubuntu:trusty
RUN apt-get update
RUN apt-get install -y  libxslt-dev libxml2-dev ruby1.9.1-dev
RUN apt-get install -y build-essential
WORKDIR /mjai
COPY . .
RUN gem build mjai.gemspec
RUN gem install ./mjai-0.0.7.gem
