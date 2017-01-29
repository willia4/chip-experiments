require 'rubygems'
require 'bundler/setup'

require 'chip-gpio'

module OLED_SSD1306
  class OLED

    attr_reader :display_width
    attr_reader :display_height

    SSD1306_SETCONTRAST = 0x81
    SSD1306_DISPLAYALLON_RESUME = 0xA4
    SSD1306_DISPLAYALLON = 0xA5
    SSD1306_NORMALDISPLAY = 0xA6
    SSD1306_INVERTDISPLAY = 0xA7
    SSD1306_DISPLAYOFF = 0xAE
    SSD1306_DISPLAYON = 0xAF

    SSD1306_SETDISPLAYOFFSET = 0xD3
    SSD1306_SETCOMPINS = 0xDA

    SSD1306_SETVCOMDETECT = 0xDB

    SSD1306_SETDISPLAYCLOCKDIV = 0xD5
    SSD1306_SETPRECHARGE = 0xD9

    SSD1306_SETMULTIPLEX = 0xA8

    SSD1306_SETLOWCOLUMN = 0x00
    SSD1306_SETHIGHCOLUMN = 0x10

    SSD1306_SETSTARTLINE = 0x40

    SSD1306_MEMORYMODE = 0x20
    SSD1306_COLUMNADDR = 0x21
    SSD1306_PAGEADDR =   0x22

    SSD1306_COMSCANINC = 0xC0
    SSD1306_COMSCANDEC = 0xC8

    SSD1306_SEGREMAP = 0xA0

    SSD1306_CHARGEPUMP = 0x8D

    SSD1306_EXTERNALVCC = 0x1
    SSD1306_SWITCHCAPVCC = 0x2

    #Scrolling Commands
    SSD1306_ACTIVATE_SCROLL = 0x2F
    SSD1306_DEACTIVATE_SCROLL = 0x2E
    SSD1306_SET_VERTICAL_SCROLL_AREA = 0xA3
    SSD1306_RIGHT_HORIZONTAL_SCROLL = 0x26
    SSD1306_LEFT_HORIZONTAL_SCROLL = 0x27
    SSD1306_VERTICAL_AND_RIGHT_HORIZONTAL_SCROLL = 0x29
    SSD1306_VERTICAL_AND_LEFT_HORIZONTAL_SCROLL = 0x2A

    DATA_COMMAND_COMMAND = 0
    DATA_COMMAND_DATA = 1

    def initialize(display_width: 128, display_height: 64, data_command_pin: null, reset_pin: null)
      raise ArgumentError, "Must pass data_command_pin" if data_command_pin == nil
      raise ArgumentError, "Must pass reset_pin" if reset_pin == nil
      
      @display_width = display_width
      @display_height = display_height

      @frame_buffer = Array.new(display_height * (display_width / 8)) { 0x00 }

      all_pins = ChipGPIO.get_pins()
      @data_command = all_pins[data_command_pin]
      @reset = all_pins[reset_pin]

      @data_command.export if not @data_command.available?
      @reset.export if not @reset.available?

      @data_command.direction = :output
      @reset.direction = :output

      @data_command.value = 0

      @spi = ChipGPIO::HardwareSPI.new
      
      @reset.value = 1
      sleep(1.0/1000)
      @reset.value = 0
      sleep(10.0/1000)
      @reset.value = 1

      send_command SSD1306_DISPLAYOFF
      send_command SSD1306_SETDISPLAYCLOCKDIV
      send_command 0x80

      send_command SSD1306_SETMULTIPLEX
      send_command @display_height - 1

      send_command SSD1306_SETDISPLAYOFFSET
      send_command 0x00

      send_command SSD1306_SETSTARTLINE | 0x0
      send_command SSD1306_CHARGEPUMP
      send_command 0x14

      send_command SSD1306_MEMORYMODE
      send_command 0x0

      send_command SSD1306_SEGREMAP | 0x1
      send_command SSD1306_COMSCANDEC

      send_command SSD1306_SETCOMPINS
      send_command 0x12

      send_command SSD1306_SETCONTRAST
      send_command 0xcf

      send_command SSD1306_SETPRECHARGE
      send_command 0xf1

      send_command SSD1306_SETVCOMDETECT
      send_command 0x40

      send_command SSD1306_DISPLAYALLON_RESUME
      send_command SSD1306_NORMALDISPLAY
      @inverted = false 

      send_command SSD1306_DEACTIVATE_SCROLL
      send_command SSD1306_DISPLAYON

      flush_pixels
    end

    def send_command(command)
      @data_command.value = DATA_COMMAND_COMMAND

      @spi.transfer_data(words: [command])
    end

    def clear_display
      @frame_buffer = Array.new(@frame_buffer.size) { 0x00 }
      flush_pixels
    end

    def flush_pixels
      send_command SSD1306_COLUMNADDR
      send_command 0x00
      send_command @display_width - 1

      send_command SSD1306_PAGEADDR
      send_command 0x00
      send_command ((display_height / 8) - 1) #for 64-wide; need to figure out how to compute this

      @data_command.value = DATA_COMMAND_DATA
      @spi.transfer_data(words: @frame_buffer)
    end

    def inverted?
      return @inverted
    end

    def inverted=(value)
      value = !!value
      @inverted = !!value

      cmd = @inverted ? SSD1306_INVERTDISPLAY : SSD1306_NORMALDISPLAY
      send_command cmd
    end

    def set_pixel(x, y, value)
      value = 0 if value < 0
      value = 1 if value > 1

      x = 0 if x < 0
      x = (@display_width - 1) if x >= @display_width

      y = 0 if y < 0
      y = (@display_height - 1) if y >= @display_height

      if value == 0
        @frame_buffer[x + (y / 8) * @display_width] &= ~(1 << (y & 7))
      else
        @frame_buffer[x + (y / 8) * @display_width] |= (1 << (y & 7))
      end
    end

    def get_pixel(x, y)
      return @frame_buffer[x + (y / 8) * @display_width] & (1 << y & 7)
    end

    def set_rectangle(x, y, width, height, value)
      (x...(x + width)).each do |t_x|
        (y...(y + height)).each do |t_y|
          set_pixel(t_x, t_y, value)
        end
      end
    end 

    def fill_rectangle(x, y, width, height)
      set_rectangle(x, y, width, height, 1)
    end

    def clear_rectangle(x, y, width, height)
      set_rectangle(x, y, width, height, 0)
    end

    def checkerboard_rectangle(x, y, width, height, check_size)
      x = 0 if x < 0
      y = 0 if y < 0
      check_size = 1 if check_size <= 0
      
      start_x = x 
      max_y = y + height
      max_x = x + width 
      max_y = @display_height if max_y > @display_height
      max_x = @display_width if max_x > @display_width

      row_start_value = 1

      while y < max_y
        x = start_x
        value = row_start_value

        while x < max_x
          set_rectangle(x, y, check_size, check_size, value)  

          value = (value == 0) ? 1 : 0
          x += check_size
        end

        row_start_value = (row_start_value == 0) ? 1 : 0
        y += check_size
      end
    end

    def set_contrast(value)
      value = 0 if value < 0
      value = 0xCF if value > 0xCF

      send_command SSD1306_SETCONTRAST
      send_command value
    end
  end
end

# def test
#   puts "Here"
#   oled = OLED_SSD1306::OLED.new(data_command_pin: :CSI1, reset_pin: :CSI3)

#   size = 16
#   x = 0
#   y = (oled.display_height / 2) - (size / 2)

#   min_x = 0
#   max_x = (oled.display_width - size)
#   min_y = y - size
#   max_y = y + size 

#   d_x = 4
#   d_y = 1

#   while true 
#     oled.checkerboard_rectangle(x, y, size, size, 2)
#     oled.flush_pixels()
#     oled.clear_rectangle(x, y, size, size)

#     x += d_x 
#     y += d_y 

#     if x >= max_x
#       x = max_x
#       d_x = -d_x
#     elsif x <= min_x
#       x = min_x
#       d_x = -d_x
#     end 

#     if y >= max_y
#       y = max_y
#       d_y = -d_y
#     elsif  y <= min_y
#       y = min_y
#       d_y = -d_y 
#     end

#     sleep(0.3)
#   end
# end

# test()