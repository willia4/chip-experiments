#!/usr/bin/env ruby

require 'snmp'
require "#{File.expand_path(File.dirname(__FILE__))}/ring_buffer.rb"

# # the host name or IP address of the the device to interrogate over snmp
# SNMP_AGENT = 'router1'    

# # the community password for the snmp agent
# SNMP_COMMUNITY = 'main'  

# # the snmp counter to average out; must be an INTEGER
# SNMP_BANDWIDTH_COUNTER_OID = "IF-MIB::ifHCInOctets.2" 

# # the number of samples to use for a rolling bandwidth average
# # a higher number will be smoother but will take longer to change
# # a lower number will be more accurate "in the moment", but may jump
# # all over the place 
# SMOOTHING_FACTOR = 10 

# # the number of seconds between samples. 
# # A lower number will be more accurate and responsive but too many 
# # samples may burden your SNMP agent or your polling device
# # A larger delay gives worse results but is also better for battery life
# SAMPLE_DELAY_SECONDS = 1.0 
  
class SpeedGetter < Object
  attr_reader :snmp_agent
  attr_reader :snmp_community
  attr_reader :snmp_counter

  def initialize(snmp_agent, snmp_community, snmp_counter, num_samples)
    @snmp_agent = snmp_agent
    @snmp_community = snmp_community
    @snmp_counter = snmp_counter

    @deltas = RingBuffer.new(num_samples)
    @took_first_sample = false 

    @last_sample = 0
  end

  def get_current_bytes
    SNMP::Manager.open(:host=>@snmp_agent, :community=>@snmp_community) do |manager|

        response = manager.get([@snmp_counter])
        var = (response.instance_eval { @varbind_list }).first

        return var.value.to_i
    end
  end

  def get_current_speed(sample_delay)
    sleep(sample_delay)
    current_sample = get_current_bytes()

    bits_per_second = 0
    kilobits_per_second = 0
    megabits_per_second = 0

    if @took_first_sample
      delta = current_sample - @last_sample
      @last_sample = current_sample

      @deltas << delta
    else
      @took_first_sample = true
      # take a second sample right now to backfill the @deltas array with a diff
      @last_sample = current_sample
      sleep(sample_delay)
      current_sample = get_current_bytes()

      delta = current_sample - @last_sample
      @last_sample = current_sample

      @deltas.max_size.times { @deltas << delta }
    end

    bits_per_second = (@deltas.mean() / sample_delay) * 8.0

    # the snmp counter can eventually roll over, which would lead to a negative
    # delta; in that case, just reset to 0. This will get smoothed out by the 
    # ring buffer once it makes another circuit 
    bits_per_second = 0 if bits_per_second < 0

    kilobits_per_second = bits_per_second / 1000.0
    megabits_per_second = kilobits_per_second / 1000.0

    return {
      :bits_per_second => bits_per_second,
      :kilobits_per_second => kilobits_per_second,
      :megabits_per_second => megabits_per_second
    }
  end
end

# $stop = false
# trap("SIGINT") { $stop = true }

# speed_getter = SpeedGetter.new(SNMP_AGENT, SNMP_COMMUNITY, SNMP_BANDWIDTH_COUNTER_OID, SMOOTHING_FACTOR)

# while !$stop
#   speed = speed_getter.get_current_speed(SAMPLE_DELAY_SECONDS)

#   if speed[:megabits_per_second] > 1
#     print "\r %.02f Mbps" % speed[:megabits_per_second]
#     print "                                           "
#   elsif speed[:kilobits_per_second] > 1
#     print "\r %.02f Kbps" % speed[:kilobits_per_second]
#     print "                                           "
#   else
#     print "\r %.02f Bps" % speed[:bits_per_second]
#     print "                                           "
#   end
      
# end

# puts ""
# puts "Quiting"
