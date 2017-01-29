require 'rubygems'
require 'bundler/setup'

require 'chip-gpio'
require './pwm_tlc5947.rb'
require './oled_ssd1306.rb'

@pwm = PWM_5947::PWM.new(latch_pin: :XIO1, data_pin: :XIO5, clock_pin: :XIO3)
@oled = OLED_SSD1306::OLED.new(data_command_pin: :CSI1, reset_pin: :CSI3)

@pwm.num_pins.times { |n| @pwm.set_value(pwm_pin: n, pwm_value: @pwm.max_value) }
@pwm.flush_values()

@oled.fill_rectangle(0, 0, @oled.display_width, @oled.display_height)
@oled.flush_pixels()