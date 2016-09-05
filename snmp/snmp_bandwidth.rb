#!/usr/bin/env ruby

require 'snmp'

ROUTER = 'router1'
COMMUNITY = 'main'
WAN = 'eth0'

IF_TREE = "1.3.6.1.2.1.2.2"
#BANDWIDTH_COUNTER_OID = "IF-MIB::ifInOctets.2"
BANDWIDTH_COUNTER_OID = "IF-MIB::ifHCInOctets.2"
class RingBuffer < Array 
  attr_reader :max_size

  def initialize(max_size)
    @max_size = max_size
    max_size.times { self << 0 }
  end

  def <<(el)
    if self.size < @max_size
      super
    else
      self.shift
      self.push(el)
    end
  end

  def sum
    return self.inject(0) { |sum, el| sum + el }
  end

  def mean 
    return self.sum / @max_size
  end

  alias :push :<<
end

def get_tree_vars(tree)
  vars = Array.new

  SNMP::Manager.open(:host=>ROUTER, :community=>COMMUNITY) do |manager|

    table = SNMP::ObjectId.new(tree)
      next_oid = table
      
      while next_oid.subtree_of?(table)
          response = manager.get_next(next_oid)
          
          varbind = response.varbind_list.first
          next_oid = varbind.name
          
          vars << varbind
      end
  end

  return vars
end

# interface_vars = get_tree_vars(IF_TREE)

# index_vars = interface_vars.select do |v| 
#   mib = v.name.instance_eval { @mib }
#   name = mib.name v.name 
#   name.start_with?("IF-MIB::ifIndex\.")
# end

# description_vars = interface_vars.select do |v| 
#   mib = v.name.instance_eval { @mib }
#   name = mib.name v.name 
#   name.start_with?("IF-MIB::ifDescr\.")
# end

# wan_description = description_vars.select do |v|
#   v.value == WAN
# end

# wan_description = wan_description.first

# wan_index = (wan_description.name.instance_eval { @mib }).name(wan_description.name)
# wan_index = /.*\.([0-9]*)/.match(wan_index).captures[0]
# wan_index = wan_index.to_i

# puts "index: #{index_vars.size}"
# puts "description: #{description_vars.first}"
# puts "#{wan_description.value}: #{wan_index}"

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
    kilobits_per_second = bits_per_second / 1000.0
    megabits_per_second = kilobits_per_second / 1000.0

    return {
      :bits_per_second => bits_per_second,
      :kilobits_per_second => kilobits_per_second,
      :megabits_per_second => megabits_per_second
    }
  end
end

$stop = false
trap("SIGINT") { $stop = true }

speed_getter = SpeedGetter.new(ROUTER, COMMUNITY, BANDWIDTH_COUNTER_OID, 10)

while !$stop
  speed = speed_getter.get_current_speed(0.5)

  if speed[:megabits_per_second] > 1
    print "\r #{speed[:megabits_per_second]} Mbps                            "
  elsif speed[:kilobits_per_second] > 1
    print "\r #{speed[:kilobits_per_second]} Kbps                            "
  else
    print "\r #{speed[:bits_per_second]} Bbps                                "
  end
      
end

puts ""
puts "Quiting"
