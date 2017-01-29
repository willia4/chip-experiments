#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'

require 'snmp'
require "./ring_buffer.rb"

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
# SMOOTHING_FACTOR = 5

# # the number of seconds between samples. 
# # A lower number will be more accurate and responsive but too many 
# # samples may burden your SNMP agent or your polling device
# # A larger delay gives worse results but is also better for battery life
# SAMPLE_DELAY_SECONDS = 0.4
  
class SpeedGetter < Object
  attr_reader :snmp_agent
  attr_reader :snmp_community
  attr_reader :snmp_counter

  def initialize(snmp_agent, snmp_community, snmp_counter, num_samples)
    raise ArgumentError, "num_samples must be greater than 1" if num_samples <= 1

    @snmp_agent = snmp_agent
    @snmp_community = snmp_community
    @snmp_counter = snmp_counter

    @deltas = RingBuffer.new(num_samples)

    @took_first_sample = false 

    @last_sample = 0

    # Create a phi-weighted average
    phi = ((1 + Math.sqrt(5))/ 2.0)
    @weights = [1]
    (num_samples - 1).times { @weights << @weights.last / phi } #num_samples - 1 because the first weight is always 1

    @samples = RingBuffer.new(num_samples)
    num_samples.times { @samples << {:time => Time.now, :bytes => get_current_bytes} }
  end

  def get_current_bytes
    SNMP::Manager.open(:host=>@snmp_agent, :community=>@snmp_community) do |manager|

        response = manager.get([@snmp_counter])
        var = (response.instance_eval { @varbind_list }).first

        return var.value.to_i
    end
  end

  #the @samples array doesn't have speeds in it; it has byte counts and timestamps
  #to figure out the speeds, you need to look at each sample and figure out how many 
  #bytes moved per unit time
  #
  #returns an array of bits-per-second values
  def get_bps_from_samples()
    bps_sum = 0
    total_weight = 0 

    #start with the second sample
    #and work forward from there
    #so we always have a previous to work from
    #work in reverse because our weights are reversed

    (1...(@samples.size)).reverse_each do |i|
      prev = @samples[i - 1]
      cur = @samples[i]

      diff_bits = (cur[:bytes] * 8) - (prev[:bytes] * 8)
      diff_seconds = cur[:time] - prev[:time]

      bps = diff_bits / diff_seconds
      bps = 0 if bps < 0

      weight = @weights[i - 1]
      total_weight += weight
      weighted_bps =  weight * bps 

      bps_sum += weighted_bps
    end

    return bps_sum / total_weight
  end

  def get_current_speed()
    new_sample = {:time => Time.now, :bytes => get_current_bytes}

    # min = @samples.min_by { |s| s[:time] }
    @samples << new_sample
    
    # diff_bytes = new_sample[:bytes] - min[:bytes]
    # diff_seconds = new_sample[:time] - min[:time]

    # bits_per_second = (diff_bytes * 8) / diff_seconds

    # bits_per_second = 0 if bits_per_second < 0

    bits_per_second = get_bps_from_samples()
    kilobits_per_second = bits_per_second / 1000.0
    megabits_per_second = kilobits_per_second / 1000.0

    return {
      :bits_per_second => bits_per_second,
      :kilobits_per_second => kilobits_per_second,
      :megabits_per_second => megabits_per_second
    }
  end
end

# speed_getter = SpeedGetter.new(SNMP_AGENT, SNMP_COMMUNITY, SNMP_BANDWIDTH_COUNTER_OID, SMOOTHING_FACTOR)

# $stop = false
# trap("SIGINT") { $stop = true }

# while !$stop
#   sleep(SAMPLE_DELAY_SECONDS)
#   speed = speed_getter.get_current_speed_2()

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
