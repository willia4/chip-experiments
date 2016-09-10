# Ping Pong Flash
Blink two LEDs back and forth, just for fun

# Install 

See README.md in parent directory for directions in installing ruby. After installing ruby, install the chip-gpio gem.

    gem install chip-gpio

# Usage

Run the script and pass in the two GPIO pins that your LEDs are attached to. If you're not root, run with `sudo`. 

    ruby ping_pong_flash.rb XIO5 XIO7

Stop the script with Ctrl-C.  