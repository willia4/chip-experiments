require 'i2c'
require 'i2c/driver/i2c-dev'

driver = I2CDevice::Driver::I2CDev.new("/dev/i2c-0", true)
device = I2CDevice.new(address: 0x34, driver: driver)

temp_msb = device.i2cget(0x5e).bytes.first << 4
temp_lsb = device.i2cget(0x5f).bytes.first & 0x0F

temp_c = ((temp_msb | temp_lsb) * 0.1) - 144.7
temp_f = (temp_c * 1.8) + 32

puts "Internal temp: #{temp_c.round(2)}°C"
puts "Internal temp: #{temp_f.round(2)}°F"

voltage_step_mV = 1.7
voltage_msb = device.i2cget(0x5A).bytes.first << 4
voltage_lsb = device.i2cget(0x5B).bytes.first & 0x0F

voltage = ((voltage_msb | voltage_lsb) * voltage_step_mV) / 1000
puts "Internal voltage: #{voltage.round(2)}V"

current_step_mA = 0.375
current_msb = device.i2cget(0x5C).bytes.first << 4
current_lsb = device.i2cget(0x5D).bytes.first & 0x0F

current = ((current_msb | current_lsb) * current_step_mA)
puts "Internal current: #{current.round(2)}mA"