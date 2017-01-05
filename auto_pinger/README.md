# CHIP Auto Pinger

[I noticed that my CHIP would become inaccessible to my Mac][forum] until the CHIP pinged the Mac. I needed a way to automate this without having terminal access to the CHIP itself (since it was inaccessible). I decided to make it complicated. 

This utility allows you to assign a GPIO button the task of pinging an arbitrary computer, or it can ping a computer every `n` seconds, or it can do both.  

It can also pulse an LED to indicate that it's performing the ping. 

[forum]: https://bbs.nextthing.co/t/chip-becomes-unreachable-over-ssh/12467/9

## Hardware Installation 

If desired, connect a button to an XIO GPIO pin on the CHIP. An XIO pin must be used because they support hardware interrupts. Connect the other end of the button to ground. 

If desired, connect an LED annode (long lead) to PWM0 and the other end to ground. In this setup, PWM0 can source several milliamps of current to the LED. Use a resistor to limit the current. 

A blue LED looks particularly nice.

## Software Installation

Once the service is installed and enabled, it should start on boot. 

#### Compile the binary
    gcc auto_pinger.c -o auto_pinger

#### Install the binary
    cp auto_pinger /usr/bin/local/auto_pinger

#### Configure the service

Edit the `auto_pinger.service` file and adjust the `ExecStart=` section.

If you want to use a hardware button to ping a system, set the --button-gpio parameter to 
the GPIO pin for your button. 

Add the --use-pwm-indicator argument if you want to hook up an LED to PWM0.

Adjust the --auto parameter to a more suitable value (in seconds) if the default doesn't work for you. Or remove --auto altogether if you want to just use a button. 

#### Example 
To use a button on XIO0, strobe an LED, and automatically ping 10.0.1.1 every 30 seconds: 

    ExecStart=/usr/local/bin/auto_pinger --button-gpio 1013 --auto 30 --use-pwm-indicator --ping-IP 10.0.1.1

#### Install the service

    cp auto_pinger.service /etc/systemd/system/auto_pinger.service
    systemctl enable /etc/systemd/system/auto_pinger.service

#### Start the service

    service auto_pinger start

You can look for messages from the service via `cat /var/log/syslog`. 

#### Stop the service

    service auto_pinger stop

#### Test the service 

    service auto_pinger start

Press the button. If the indicator light is hooked up, it should pulse for a few seconds while the ping is active. 

## Motivation

This small project gave me the opportunity to experiment with a few new things. 

It's written in C, a language I haven't touched since college. Which is to say, it's written in very bad C. 

It uses the epoll function to watch for hardware interrupts on the GPIO pin. 

Because it uses timerfd support, it also uses epoll to watch for timer events. This was a really pleasant way to do things. 

It uses the PWM0 pin to pulse an LED instead of just having it be on or off. 

It uses `fork` instead of threads for parallel processing. I've never done this before. So I am almost certainly doing it poorly. 
