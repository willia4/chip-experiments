#include <sys/epoll.h>
#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <signal.h>
#include <stdlib.h>
#include <stdbool.h>
#include <limits.h>
#include <sys/types.h>
#include <dirent.h>
#include <assert.h>

#define debug_printf //printf
#define fork_printf //printf 

static inline void increment_progress() {
	//fwrite(".", sizeof(char), 1, stdout);
	//fflush(stdout);
}

typedef struct argumentInfo_t {
	int buttonGpio;
	bool usePWM;
	char *pingIP;
} argumentInfo_t;

// Process-Wide Variables
int button_fd;
int pwm_fd; 

#define PWM_MAX 1000

void write_pwm(int pwm_fd, double percent) {
	assert(pwm_fd > 0);
	assert(percent >= 0);
	assert(percent <= 100.0);

	int value = (percent/100.0) * (double)(PWM_MAX);

	char buf[5];

	snprintf(buf, 5, "%d", value);
	write(pwm_fd, buf, strlen(buf));
}

bool dir_exists(char *path) {
	DIR *dir = opendir(path);
	if (dir) {
		closedir(dir);
		return true;
	}
	else {
		return false;
	}
}

void write_to_path(char *file_path, char *value) {
	int fd = open(file_path, O_WRONLY);
	write(fd, value, strlen(value));
	sleep(1);
	close(fd);
}

static inline int signal_and_wait(pid_t pid, int signal) {
	kill(pid, signal);

	int status;
	pid_t wpid = waitpid(pid, &status, 0);
	assert(wpid == pid);

	return status;
}

void init_button(int button_gpio) {
	char button_base_path[PATH_MAX];

	char temp_path[PATH_MAX];
	char temp_buf[1024]; 

	snprintf(button_base_path, PATH_MAX, "/sys/class/gpio/gpio%d/", button_gpio);

	//see if the base button path exists; if not, export the gpio
	//This should NOT be done if it's already exported (hence the check)
	debug_printf("Looking at %s to see if the GPIO button is exported\n", button_base_path);
	increment_progress();

	if (dir_exists(button_base_path)) {
		debug_printf("Pin is already exported\n");
		increment_progress();
	}
	else {
		debug_printf("Exporting GPIO pin %d\n", button_gpio);

		snprintf(temp_buf, 1024, "%d", button_gpio);
		debug_printf("Going to write %s to the export file\n", temp_buf);

		write_to_path("/sys/class/gpio/export", temp_buf);
		increment_progress();
	}

	//make sure the direction is set correctly; this is okay to do even if it's been done before
	debug_printf("Setting direction on GPIO pin %d\n", button_gpio);
	snprintf(temp_path, PATH_MAX, "%sdirection", button_base_path);
	debug_printf("Writing \"in\" to %s", temp_path);
	write_to_path(temp_path, "in");
	increment_progress();

	//make sure the interrupt edge is set correctly; this is okay to do even if it's been done before
	debug_printf("Setting interrupt edge on GPIO pin %d\n", button_gpio);
	snprintf(temp_path, PATH_MAX, "%sedge", button_base_path);
	debug_printf("Writing \"both\" to %s\n", temp_path);
	write_to_path(temp_path, "both");
	increment_progress();

	//make sure the active_low is set correctly; this is okay to do even if it's been done before
	debug_printf("Setting active_low on GPIO pin %d\n", button_gpio);
	snprintf(temp_path, PATH_MAX, "%sactive_low", button_base_path);
	debug_printf("Writing \"0\" to %s\n", temp_path);
	write_to_path(temp_path, "0");
	increment_progress();

	//Open button value and save file descriptor
	debug_printf("Opening value file for GPIO pin %d\n", button_gpio);
	snprintf(temp_path, PATH_MAX, "%svalue", button_base_path);
	debug_printf("Opening %s\n", temp_path);
	button_fd = open(temp_path, O_RDONLY | O_NONBLOCK);
	increment_progress();
}

void init_pwm() {	
	char temp_path[PATH_MAX];
	char temp_buf[1024]; 

	debug_printf("Looking at /sys/class/pwm/pwmchip0/pwm0/ to see if the PWM pin is exported\n");
	increment_progress();
	if (dir_exists("/sys/class/pwm/pwmchip0/pwm0/")) {
		debug_printf("Pin is already exported\n");
		increment_progress();
	}
	else {
		debug_printf("Exporting PWM pin\n");
		debug_printf("Going to write 0 to the export file\n");

		write_to_path("/sys/class/pwm/pwmchip0/export", "0");
		increment_progress();
	}

	debug_printf("Disabling PWM pin\n");
	write_to_path("/sys/class/pwm/pwmchip0/pwm0/enable", "0");
	increment_progress();

	debug_printf("Setting PWM polarity\n");
	write_to_path("/sys/class/pwm/pwmchip0/pwm0/polarity", "normal");	
	increment_progress();

	debug_printf("Enabling PWM pin\n");
	write_to_path("/sys/class/pwm/pwmchip0/pwm0/enable", "1");
	increment_progress();

	debug_printf("Setting PWM duty_cycle to 0\n");
	write_to_path("/sys/class/pwm/pwmchip0/pwm0/duty_cycle", "0");
	increment_progress();

	debug_printf("Setting PWM period to %d ns\n", PWM_MAX);
	snprintf(temp_buf, 1024, "%d", PWM_MAX);
	write_to_path("/sys/class/pwm/pwmchip0/pwm0/period", temp_buf);
	increment_progress();

	debug_printf("Opening PWM duty_cycle file descriptor");
	pwm_fd = open("/sys/class/pwm/pwmchip0/pwm0/duty_cycle", O_RDWR | O_NONBLOCK);
	increment_progress();
}

void init(int button_gpio, bool usePWM) {
	button_fd = 0;
	pwm_fd = 0;

	init_button(button_gpio);

	if(usePWM) {
		init_pwm();	
	}

	printf("\n");
}

void pulse_signal_handler(int sig_num) {
	exit(0);
}

void stop_pulse(pid_t pid) {
	if (!pid) {
		return;
	}
	
	signal_and_wait(pid, SIGHUP);
	
	char buf[1024];
	lseek(pwm_fd, 0, SEEK_SET);
	read(pwm_fd, &buf, 1023);

	int value = atoi(buf);
	double percent = ((double)value / (double)(PWM_MAX)) * 100.0;

	for(;percent >= 0; percent-=.5) {
		write_pwm(pwm_fd, percent);
		usleep(3500);
	}

	write(pwm_fd, "0", 1);
}

pid_t pulse_led() {
	if (!pwm_fd) {
		return 0;
	}

	pid_t pid = fork();
	if (pid == 0) {
		signal(SIGHUP, pulse_signal_handler);

		int max = 1000;
		double percent = 0; 

		char buf[1024];

		while(1) {
			for(percent = 0; percent <= 99.5; percent+=.5) {
				write_pwm(pwm_fd, percent);
				usleep(7000);
			}

			for(percent = 100; percent >= 0; percent-=.5) {
				write_pwm(pwm_fd, percent);
				usleep(3500);
			}
		}
		
		exit(0);
	}

	return pid;
}

void do_ping(char *pingIP) {
	char* argv[] = {"ping", "-c 30", pingIP, NULL};

	pid_t ping_pid = fork();

	if (ping_pid == 0) {
		execvp(argv[0], argv);
		printf("Should never get here\n");
	}

	printf("Pinging on PID %d\n", ping_pid);

	pid_t pulse_pid = pulse_led();

	printf("Pulsing on PID %d\n", pulse_pid);

	sleep(5);

	signal_and_wait(ping_pid, SIGTERM);
	
	stop_pulse(pulse_pid);
}

extern char *__progname;
void exit_usage(char *error) {
	if (error) {
		printf("\n");
		printf("%s\n", error);
	}

	printf("\n");
	printf("Usage: %s --ping-IP {IP Address} --button-gpio {INT} [--use-pwm-indicator]\n\n", __progname);
	printf("\t--ping-IP {IP Address}\t\tRequired: The IP address to ping when the button is pressed\n");
	printf("\t--button-gpio {INT}\t\tRequired: The GPIO pin to monitor\n");
	printf("\t--use-pwm-indicator\t\tOptional: Pulse an LED connected to PWM0\n");
	printf("\n\n");
	printf("The GPIO pin for the button must be an XIO pin. These support \n");
	printf("interrupts.\n");
	printf("\n");
	printf("--use-pwm-indicator assumes that pwmchip0 has been enabled in\n");
	printf("the device tree.\n");
	printf("\n");

	exit(1);
}

argumentInfo_t parse_arguments(int argc, char **argv) {
	argumentInfo_t r; 

	r.buttonGpio = -1;
	r.usePWM = false;
	r.pingIP = NULL;

	bool sawButtonGpio = false;
	bool sawUsePWM = false; 
	bool sawPingIP = false; 

	char errorMessage[1024];
	char *parseEnd;

	int i; 

	char *currentArg;
	char *nextArg;

	for(i = 1; i < argc; i++) {
		currentArg = argv[i];

		if(strcmp(currentArg, "--button-gpio") == 0) {
			if(sawButtonGpio) {
				exit_usage("--button-gpio can only be specified once");
			}
			sawButtonGpio = true;

			i++; 
			if(i >= argc) {
				exit_usage("Must supply integer for --button-gpio argument");
			}

			nextArg = argv[i];
			r.buttonGpio = strtol(nextArg, &parseEnd, 10);
			if(*parseEnd) {
				exit_usage("Must supply integer for --button-gpio argument");
			}
		}
		else if(strcmp(currentArg, "--use-pwm-indicator") == 0) {
			if(sawUsePWM) {
				exit_usage("--use-pwm-indicator can only be specified once");
			}
			sawUsePWM = true;

			r.usePWM = true;
		}
		else if(strcmp(currentArg, "--ping-IP") ==0) {
			if(sawPingIP) {
				exit_usage("--ping-IP can only be specified once");
			}
			sawPingIP = true;

			i++;
			if(i > argc) {
				exit_usage("Must supply an IP address after --ping-IP");
			}
			nextArg = argv[i];
			r.pingIP = nextArg;
		}
		else {
			snprintf(errorMessage, 1024, "Invalid argument: %s", currentArg);
			exit_usage(errorMessage);
		}
	}

	if(!sawButtonGpio) {
		exit_usage("--button-gpio is required");
	}
	if(!sawPingIP) {
		exit_usage("--ping-IP is required");
	}

	return r;
}

void forked_main(argumentInfo_t args) {
	char buf[1024];
	int ready_fd; 

	printf("*** Initializing System *** \n");
	init(args.buttonGpio, args.usePWM);

	debug_printf("Reading value before polling\n");
	lseek(button_fd, 0, SEEK_SET);
	read(button_fd, &buf, 1023);

	int epfd = epoll_create(1);
	
	struct epoll_event poll_data;
	struct epoll_event poll_ready;

	poll_data.events = EPOLLPRI;
	poll_data.data.fd = button_fd;

	int n = epoll_ctl(epfd, EPOLL_CTL_ADD, button_fd, &poll_data);

	printf("*** READY ***\n\n");

	while(1) {
		debug_printf("Polling\n");
		n = epoll_wait(epfd, &poll_ready, 1, -1);
		debug_printf("epoll returned\n");

		memset(&buf, 0, 1024 * sizeof(char));

		n = lseek(button_fd, 0, SEEK_SET);
		n = read(button_fd, &buf, 1024);

		buf[1023] = '\0';
		debug_printf("Read: %s\n", buf);

		//if (buf[0] == '1') {
		if(strncmp(buf, "1\n", n) == 0) {
			do_ping(args.pingIP);	
		}
	}
}

int main(int argc, char **argv) {
	argumentInfo_t args = parse_arguments(argc, argv);

	pid_t pid = fork();

	if (pid < 0) {
		printf("Could not fork a daemon process\n");
		exit(100);
	}

	if (pid > 0) {
		//kill the parent process 
		printf("Process forked to %d\n", pid);
		exit(0);
	}

	pid_t sid = setsid();
	if (sid < 0) {
		exit(200);
	}

	forked_main(args);
	return -1;
}