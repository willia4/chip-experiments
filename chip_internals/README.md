# Chip Internals

A small ruby script to retrieve some internal data from the CHIP computer.

Currently prints the internal temperature in Celsius and Fahrenheit, current internal voltage in volts, and current current consumption in milliamps. 

## Pre-reqs

See README.md in parent directory for directions in installing ruby and the i2c-devices gem on your CHIP. 

## Usage

	This script require root privileges. If you are not running as root, use `sudo`.

    ruby chip_internals.rb

    Internal temp: 39.2°C
    Internal temp: 102.56°F
    Internal voltage: 4.94V
    Internal current: 372.0mA