#!/usr/bin/python3

import serial
import sys
import threading
import subprocess
import signal

# Serial configuration
SERIAL_PORT = "/dev/ttyACM0"
BAUD_RATE = 115200
XMODEM_FILE = "./tftpboot/u-boot-spl-restore.bin"
YMODEM_FILE = "./tftpboot/u-boot-restore.img"

# Open serial port
ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=0.1)

def signal_handler(sig, frame):
    print("\n[INFO] Terminating...")
    ser.close()
    sys.exit(0)

# Register signal handler for CTRL+X
signal.signal(signal.SIGINT, signal_handler)

def read_serial():
    """ Continuously read from serial and print to stdout. """
    while True:
        try:
            data = ser.read(1024)
            if data:
                sys.stdout.write(data.decode(errors='ignore'))
                sys.stdout.flush()
        except Exception as e:
            print(f"[ERROR] Serial read error: {e}")
            break

def wait_for_signal(signal_char):
    """ Wait for a single occurrence of a specific signal in the serial output. """
    print(f"[INFO] Waiting for signal: {signal_char}")
    while True:
        try:
            data = ser.read(1).decode(errors='ignore')
            if data:
                sys.stdout.write(data)
                sys.stdout.flush()
                if signal_char in data:
                    print(f"[INFO] Detected signal: {signal_char}")
                    return
        except Exception as e:
            print(f"[ERROR] Serial read error: {e}")
            break

def send_file_xmodem():
    """ Wait for a single 'C' before sending XMODEM file. """
    wait_for_signal("C")
    print(f"[INFO] Sending {XMODEM_FILE} via XMODEM...")
    subprocess.run(["lrzsz-sx", "-X", XMODEM_FILE], stdin=ser, stdout=ser)
    print("[INFO] XMODEM transfer complete.")

def send_file_ymodem():
    """ Wait for a single 'C' before sending YMODEM file. """
    wait_for_signal("C")
    print(f"[INFO] Sending {YMODEM_FILE} via YMODEM...")
    subprocess.run(["lrzsz-sx", "-Y", YMODEM_FILE], stdin=ser, stdout=ser)
    print("[INFO] YMODEM transfer complete.")

def user_input():
    """ Allow user input to be sent to serial. """
    while True:
        try:
            data = sys.stdin.read(1)
            if data == "\x18":  # CTRL+X
                signal_handler(None, None)
            ser.write(data.encode())
        except Exception as e:
            print(f"[ERROR] User input error: {e}")
            break

# Start reading serial output
serial_thread = threading.Thread(target=read_serial, daemon=True)
serial_thread.start()

# Start user input thread
input_thread = threading.Thread(target=user_input, daemon=True)
input_thread.start()

# Send XMODEM file after detecting 'C'
send_file_xmodem()

# Send YMODEM file after detecting 'C'
send_file_ymodem()

# Keep main thread alive to allow interaction
serial_thread.join()
input_thread.join()
