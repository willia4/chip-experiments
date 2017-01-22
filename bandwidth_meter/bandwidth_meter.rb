require 'rubygems'
require 'bundler/setup'

require 'chip-gpio'
require './snmp_bandwidth.rb'
require './pwm_tlc5947.rb'

# the host name or IP address of the the device to interrogate over snmp
SNMP_AGENT = 'router1'    

# the community password for the snmp agent
SNMP_COMMUNITY = 'main'  

# the snmp counter to average out; must be an INTEGER
SNMP_DOWNLOAD_COUNTER_OID = "IF-MIB::ifHCInOctets.2" 
SNMP_UPLOAD_COUNTER_OID = "IF-MIB::ifHCOutOctets.2" 

# the number of samples to use for a rolling bandwidth average
# a higher number will be smoother but will take longer to change
# a lower number will be more accurate "in the moment", but may jump
# all over the place 
SMOOTHING_FACTOR = 3

# the number of seconds between samples. 
# A lower number will be more accurate and responsive but too many 
# samples may burden your SNMP agent or your polling device
# A larger delay gives worse results but is also better for battery life
SAMPLE_DELAY_SECONDS = 0.1

# The max expected bandwidth; this is the bandwidth that will appear
# as 100%. Any bandwidth higher than this will be show as 100% for
# display purposes
MAX_DOWNLOAD_KBS = 37000
MAX_UPLOAD_KBS = 8000

@download_getter = SpeedGetter.new(SNMP_AGENT, SNMP_COMMUNITY, SNMP_DOWNLOAD_COUNTER_OID, SMOOTHING_FACTOR)
@upload_getter = SpeedGetter.new(SNMP_AGENT, SNMP_COMMUNITY, SNMP_UPLOAD_COUNTER_OID, SMOOTHING_FACTOR)

@pwm = PWM_5947::PWM.new(latch_pin: :XIO1, data_pin: :XIO5, clock_pin: :XIO3)



#@pwm.set_value(pwm_pin: download_meter_pwm_pin, pwm_value: 3000)
#@pwm.flush_values()

#show_activity()

def show_bandwidth(pwm_pin, bandwidth_kbps, max_bandwidth)
  percent = (bandwidth_kbps / max_bandwidth)
  percent = 1 if percent > 1

  pwm_value = (percent * @pwm.max_value).ceil
  puts "#{pwm_pin}pin #{bandwidth_kbps}: #{percent * 100}% : #{pwm_value}"

  @pwm.set_value(pwm_pin: pwm_pin, pwm_value: pwm_value)
  @pwm.flush_values()
end

download_meter_pwm_pin = 18
upload_meter_pwm_pin = 12

# Waggle the meters just to prove that it's working
  @pwm.set_value(pwm_pin: download_meter_pwm_pin, pwm_value: (0.75 * @pwm.max_value).ceil)
  @pwm.set_value(pwm_pin: upload_meter_pwm_pin, pwm_value: (0.25 * @pwm.max_value).ceil)
  @pwm.flush_values()
  sleep(0.2)

  @pwm.set_value(pwm_pin: download_meter_pwm_pin, pwm_value: (0.25 * @pwm.max_value).ceil)
  @pwm.set_value(pwm_pin: upload_meter_pwm_pin, pwm_value: (0.75 * @pwm.max_value).ceil)
  @pwm.flush_values()
  sleep(0.2)

  @pwm.set_value(pwm_pin: download_meter_pwm_pin, pwm_value: 0)
  @pwm.set_value(pwm_pin: upload_meter_pwm_pin, pwm_value: 0)
  @pwm.flush_values()
# End waggle

$stop = $false
trap("SIGINT") { $stop = true }

while !$stop
  begin  
    break if $stop
    download = @download_getter.get_current_speed()
  rescue => e
    puts "Download Exception: #{e}"

    download = {
      :bits_per_second => 0,
      :kilobits_per_second => 0,
      :megabits_per_second => 0
    }
  end

  begin
    break if $stop
    upload = @upload_getter.get_current_speed()
  rescue => e
    puts "Upload Exception: #{e}"

    upload = {
      :bits_per_second => 0,
      :kilobits_per_second => 0,
      :megabits_per_second => 0
    }
  end

  begin
    break if $stop
    show_bandwidth(download_meter_pwm_pin, download[:kilobits_per_second], MAX_DOWNLOAD_KBS)
  rescue => e
    puts "Error showing download bandwidth: #{e}"
  end

  begin
    break if $stop
    show_bandwidth(upload_meter_pwm_pin, upload[:kilobits_per_second], MAX_UPLOAD_KBS)  
  rescue => e
    puts "Error showing upload bandwidth: #{e}"
  end

  break if $stop
  sleep(SAMPLE_DELAY_SECONDS)
end

@pwm.reset_all()
