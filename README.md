# CHIP Experiments

These are some experiments with the [CHIP](https://nextthing.co/pages/chip) computer. 

## Experiment 1: Reading environmental data from the AXP209 Power Controller

The `chip_internals.rb` script can report the temperature (in Centigrade and Fahrenheit) of the CHIP. 

It can also report the operating voltage and current of the CHIP. Handy stuff! 

It does this by querying the AXP209 controller. The registers are documented in the AXP209 data sheet: [https://github.com/NextThingCo/CHIP-Hardware/blob/master/CHIP%5Bv1_0%5D/CHIPv1_0-BOM-Datasheets/AXP209_Datasheet_v1.0en.pdf](https://github.com/NextThingCo/CHIP-Hardware/blob/master/CHIP%5Bv1_0%5D/CHIPv1_0-BOM-Datasheets/AXP209_Datasheet_v1.0en.pdf).

## Prereqs

I like ruby for prototyping. You'll need to install it on your CHIP to use most of these. 

### Ruby Installation

These are installation instructions for root (adjust as needed if you use an unprivileged user): 

#### Install build dependencies. 
Not all of these are needed but I expect to want some of
them later so I'm throwing them all in for now. Adjust to taste.

    apt-get -y install wget curl build-essential zlib1g-dev libssl-dev libreadline-gplv2-dev libxml2-dev  libsqlite3-dev libffi6 libffi-dev

#### Download ruby

    wget http://cache.ruby-lang.org/pub/ruby/ruby-2.3.1.tar.gz

#### Unarchive ruby

    tar -xvf ruby-2.3.1.tar.gz
    cd ruby-2.3.1

#### Build ruby

    ./configure && make && make install

### Gems

You may need to install gems for these scripts. It should be obvious from the `require` statements at the top of the scripts. `gem install GEMNAME` usually gets the job done. 

The `i2c-devices` library (referenced as `require "i2c"`) is extremely useful for doing things
with CHIP. Unfortunately, the current version of this library (0.0.5) does not support forcing commands over the i2c bus. This is a requirement for interacting with the AXP209 chip. 

The "force" feature has been merged into the library; but until a new version is published, you'll need to build the code. 
 
#### Install git

    apt-get -y install git

#### Clone the current i2c-devices code
    cd
    git clone https://github.com/cho45/ruby-i2c-devices.git

#### Build and install the development version of the gem

    cd ruby-i2c-devices
    gem build i2c-devices.gemspec
    gem install --local i2c-devices-0.0.5.gem 
