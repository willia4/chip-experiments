require 'rubygems'
require 'bundler/setup'

require 'chip-gpio'
require './snmp_bandwidth.rb'
require './pwm_tlc5947.rb'
require './oled_ssd1306.rb'
require './ring_buffer.rb'

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
SMOOTHING_FACTOR = 5

# the number of seconds between samples. 
# A lower number will be more accurate and responsive but too many 
# samples may burden your SNMP agent or your polling device
# A larger delay gives worse results but is also better for battery life
SAMPLE_DELAY_SECONDS = 1.0

# The max expected bandwidth; this is the bandwidth that will appear
# as 100%. Any bandwidth higher than this will be show as 100% for
# display purposes
MAX_DOWNLOAD_KBS = 37000
MAX_UPLOAD_KBS = 8000

# The past N measurements to display on the screen 
# Each bar will be ((screenWidth / 2) - 1) pixels high
# (with one pixel used as a separator for the next bar)
# so keep the screenWidth in mind while setting this. \
HISTORY_COUNT = 64

@download_getter = SpeedGetter.new(SNMP_AGENT, SNMP_COMMUNITY, SNMP_DOWNLOAD_COUNTER_OID, SMOOTHING_FACTOR)
@upload_getter = SpeedGetter.new(SNMP_AGENT, SNMP_COMMUNITY, SNMP_UPLOAD_COUNTER_OID, SMOOTHING_FACTOR)

@pwm = PWM_5947::PWM.new(latch_pin: :XIO1, data_pin: :XIO5, clock_pin: :XIO3)
@oled = OLED_SSD1306::OLED.new(data_command_pin: :CSI1, reset_pin: :CSI3)

def show_bandwidth(pwm_pin, bandwidth_kbps, max_bandwidth)
  percent = (bandwidth_kbps / max_bandwidth)
  percent = 1 if percent > 1

  pwm_value = (percent * @pwm.max_value).ceil
  puts "pin #{pwm_pin} - #{bandwidth_kbps.round(5)} kbps"

  @pwm.set_value(pwm_pin: pwm_pin, pwm_value: pwm_value)
end

def draw_history 
  width_gutter = 1
  width = (@oled.display_width / HISTORY_COUNT)

  height_gutter = 1
  height = (@oled.display_height / 2) - height_gutter

  download_y = 0
  upload_y = download_y + height + height_gutter
  
  @oled.clear_display()

  x = 0
  @history.each_index do |i|
    cur = @history[i]
    
    upload_percent = (cur[:upload] / (MAX_UPLOAD_KBS + 0.0))
    upload_height = (upload_percent * height).ceil
    upload_height = height if upload_height > height 

    download_percent = (cur[:download] / (MAX_DOWNLOAD_KBS + 0.0))
    download_height = (download_percent * height).ceil
    download_height = height if download_height > height 

    y = download_y + (height - download_height)
    @oled.fill_rectangle(x, y, width - width_gutter, download_height)

    y = upload_y + (height - upload_height)
    @oled.fill_rectangle(x, y, width - width_gutter, upload_height)

    x += width
  end
end

download_meter_pwm_pin = 18
upload_meter_pwm_pin = 12
backlight_pwm_pin = 11

# Waggle the meters just to prove that it's working
  @pwm.set_value(pwm_pin: download_meter_pwm_pin, pwm_value: (0.75 * @pwm.max_value).ceil)
  @pwm.set_value(pwm_pin: upload_meter_pwm_pin, pwm_value: (0.25 * @pwm.max_value).ceil)
  @pwm.set_value(pwm_pin: backlight_pwm_pin, pwm_value: (0.25 * @pwm.max_value).ceil)

  @oled.clear_display()
  @oled.fill_rectangle(0, 0, @oled.display_width, @oled.display_height)
  @oled.clear_rectangle(32, 16, 64, 32)
  @pwm.flush_values()
  @oled.flush_pixels()

  sleep(0.2)

  @pwm.set_value(pwm_pin: download_meter_pwm_pin, pwm_value: (0.25 * @pwm.max_value).ceil)
  @pwm.set_value(pwm_pin: upload_meter_pwm_pin, pwm_value: (0.75 * @pwm.max_value).ceil)
  @pwm.set_value(pwm_pin: backlight_pwm_pin, pwm_value: (0.75 * @pwm.max_value).ceil)
  @pwm.flush_values()
  
  @oled.checkerboard_rectangle(32, 16, 64, 32, 4)
  @oled.flush_pixels()

  sleep(0.2)

  @pwm.set_value(pwm_pin: download_meter_pwm_pin, pwm_value: 0)
  @pwm.set_value(pwm_pin: upload_meter_pwm_pin, pwm_value: 0)
  @pwm.set_value(pwm_pin: backlight_pwm_pin, pwm_value: 0)
  @oled.clear_display()
  @oled.inverted = false
  @oled.flush_pixels()
  @pwm.flush_values()
# End waggle

$stop = $false
trap("SIGINT") { $stop = true }

@history = RingBuffer.new(HISTORY_COUNT)
HISTORY_COUNT.times { @history << {:upload => 0, :download => 0} }

@pwm.set_value(pwm_pin: backlight_pwm_pin, pwm_value: @pwm.max_value)

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

  @history << {:upload => upload[:kilobits_per_second], :download => download[:kilobits_per_second]}
  draw_history()

  break if $stop

  @oled.flush_pixels()
  @pwm.flush_values()
  
  sleep(SAMPLE_DELAY_SECONDS)
end

@pwm.reset_all()
@oled.clear_display()
@oled.flush_pixels()