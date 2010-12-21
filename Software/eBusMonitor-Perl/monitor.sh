#/bin/bash
stty -F /dev/ttyUSB0 2400
jpnevulator --ascii --tty /dev/ttyUSB0 --read

