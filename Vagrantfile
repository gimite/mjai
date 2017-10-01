# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/trusty64"

  config.vm.network "forwarded_port", guest: 11600, host: 11600

  config.vm.provision "shell", inline: <<-SHELL
    sudo apt-get install -y libxslt-dev libxml2-dev
    sudo apt-get install -y ruby1.9.1-dev
    cd /vagrant/
    gem build mjai.gemspec
    sudo gem install ./mjai-0.0.7.gem
  SHELL
end
