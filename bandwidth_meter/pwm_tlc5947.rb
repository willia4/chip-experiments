require 'rubygems'
require 'bundler/setup'

require 'chip-gpio'

module PWM_5947
  class PWM    
    attr_reader :num_pins
    attr_reader :resolution_bits
    attr_reader :max_value 

    def initialize(latch_pin: null, clock_pin: null, data_pin: null)
      @num_pins = 24
      @resolution_bits = 12

      @spi = ChipGPIO::SoftSPI.new(clock_pin: clock_pin, output_pin: data_pin, word_size: @resolution_bits, polarity: 1)
      @max_value = @spi.max_word


      @latch = ChipGPIO.get_pins()[latch_pin]
      @latch.export if not @latch.available?
      @latch.direction = :output
      @latch.value = 0

      @values = Array.new
      @num_pins.times { @values << 0 }

      self.reset_all()
    end

    def values 
      r = Array.new
      @values.each { |v| r.push(v) }
      return r
    end

    def set_value(pwm_pin: null, pwm_value: null)
      # Raise an error if they don't specify a valid pin
      raise ArgumentError, "Must specify a PWM pin" if !pwm_pin
      raise ArgumentError, "PWM pin must be greater than 0" if pwm_pin < 0
      raise ArgumentError, "PWM pin must be less than #{@num_pins}" if pwm_pin >= @num_pins

      # But an invalid value is fine since we know how to clamp it sanely
      pwm_value = 0 if !pwm_value
      pwm_value = 0 if pwm_value < 0
      pwm_value = @max_value if pwm_value > @max_value

      @values[pwm_pin] = pwm_value
    end

    def flush_values()
      #the chip expects pin 0 to be the last pin it sees so we need to 
      #reverse the array before writing it out (so values[0] will be the last 
      #word written )
      @spi.write(words: @values.reverse())
      
      #toggle the latch to actually update the output pins
      @latch.value = 1
      @latch.value = 0
    end

    def reset_all
      num_pins.times.each { |i| @values[i] = 0 }
      flush_values()
    end

  end
end

# def test 
#   pwm = PWM_5947::PWM.new(latch_pin: :XIO1, data_pin: :XIO5, clock_pin: :XIO3)
  
#   meters = Array.new()
#   meters.push({ :pin=> 18, :value=> 0, :direction => :ascending })
#   meters.push({ :pin => 12, :value=> pwm.max_value, :direction => :descending })
#   step = (0.10 * pwm.max_value).ceil

#   $stop = false 
#   trap("SIGINT") { $stop = true }

#   while !$stop
#     meters.each do |m|
#       if m[:direction] == :ascending
#         m[:value] = m[:value] + step 

#         if (m[:value] > pwm.max_value) 
#           m[:value] = pwm.max_value
#           m[:direction] = :descending
#         end
#       else
#         m[:value] = m[:value] - step 

#         if (m[:value] < 0) 
#           m[:value] = 0
#           m[:direction] = :ascending
#         end
#       end

#       pwm.set_value(pwm_pin: (m[:pin]), pwm_value: (m[:value]))
#     end

#     pwm.flush_values if !$stop

#     sleep(0.005) if !$stop
#   end

#   #animate to zero
#   can_stop = false
#   while !can_stop
#     values = pwm.values 
#     can_stop = true 

#     values.each_with_index do |v, i|
#       if v > 0
#         can_stop = false
#         pwm.set_value(pwm_pin: i, pwm_value: (v - (step * 2)))
#       end
#     end

#     pwm.flush_values if !can_stop
#     sleep(0.005) if !can_stop
#     break if can_stop
#   end
# end

# #test()