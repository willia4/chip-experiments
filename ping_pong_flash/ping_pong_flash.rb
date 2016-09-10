require 'chip-gpio'

throw "Must pass in two arguments" if ARGV.size != 2

pin1_name = ARGV[0].to_sym
pin2_name = ARGV[1].to_sym

puts "Using #{pin1_name} as LED 1"
puts "Using #{pin2_name} as LED 2"

pins = ChipGPIO.get_pins

throw "#{pin1_name} is not a valid pin" if !pins.has_key?(pin1_name)
throw "#{pin2_name} is not a valid pin" if !pins.has_key?(pin2_name)

pin1 = pins[pin1_name]
pin2 = pins[pin2_name]

pin1.export if !pin1.available?
pin2.export if !pin2.available?

throw "Could not export #{pin1_name}" if !pin1.available?
throw "Could not export #{pin2_name}" if !pin2.available?

pin1.direction = :output
pin2.direction = :output

throw "Could not set #{pin1_name} to output" if pin1.direction != :output
throw "Could not set #{pin2_name} to output" if pin2.direction != :output

while true
  pin1.value = 0
  pin2.value = 1

  sleep(0.7)

  pin1.value = 1
  pin2.value = 0

  sleep(0.7)
end