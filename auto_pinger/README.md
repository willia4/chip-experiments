# CHIP Auto Pinger

[I noticed that my CHIP would become inaccessible to my Mac][forum] until the CHIP pinged the Mac. I needed a way to automate this without having terminal access to the CHIP itself (since it was inaccessible). I decided to make it complicated. 

This utility allows you to assign a GPIO button the task of pinging an arbitrary computer. 

It can also pulse an LED to indicate that it's performing the ping. 

[forum]: https://bbs.nextthing.co/t/chip-becomes-unreachable-over-ssh/12467/9

## Hardware Installation 

Connect a button to an XIO GPIO pin on the CHIP. An XIO pin must be used because they support hardware interrupts. Connect the other end of the button to ground. 

If desired, connect an LED annode (long lead) to PWM0 and the other end to ground. In this setup, PWM0 can source several milliamps of current to the LED. Use a resistor to limit the current. 

A blue LED looks particularly nice.

## Software Installation

Once the service is installed and enabled, it should start on boot. 

#### Compile the binary
    gcc auto_pinger.c -o auto_pinger

#### Install the binary
    cp auto_pinger /usr/bin/local/auto_pinger

#### Configure the service

Edit the `auto_pinger.service` file and set the --button-gpio parameter and --ping-IP parameter to the correct values for your setup. Remove the --use-pwm-indicator argument if you have not hooked up an LED to PWM0. 

#### Install the service

    cp auto_pinger.service /etc/systemd/system/auto_pinger.service
    systemctl enable /etc/systemd/system/auto_pinger.service

#### Start the service

    service auto_pinger start

#### Stop the service

    service auto_pinger stop

#### Test the service 

    service auto_pinger start

Press the button. If the indicator light is hooked up, it should pulse for a few seconds while the ping is active. 

## Motivation

This small project gave me the opportunity to experiment with a few new things. 

It's written in C, a language I haven't touched since college. Which is to say, it's written in very bad C. 

It uses the epoll function to watch for hardware interrupts on the GPIO pin. 

It uses the PWM0 pin to pulse an LED instead of just having it be on or off. 

It uses `fork` instead of threads for parallel processing. I've never done this before. So I am almost certainly doing it poorly. 

## The Future

This is actually a very silly way to accomplish this goal. It ties up two pins that I would prefer to use for something else. 

My next project will be to make it automatically ping the other computer every `n` seconds. Then it can simply run in the background while I do other things. But this seemed like a good opportunity to play with buttons and interrupts so I did it first. 

I also don't enjoy writing in C and need to figure out how to use `epoll` (or similar) to watch for GPIO pins from ruby or python. 
