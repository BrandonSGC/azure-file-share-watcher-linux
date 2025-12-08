# Azure File Share Watcher - Linux

Mini project to build a lightweight monitoring system using:

- **Azure File Share (Azure Storage Account – File Service)**
- **Linux Virtual Machine**
- **inotifywait** to detect file system events
- **systemd service** to keep the watcher running automatically

---

## 📌 Project Overview

The system works like this:

1. A **Linux VM** mounts an **Azure File Share** using the CIFS protocol.
2. A **Bash script** (`az-files-watcher.sh`) uses `inotifywait` to detect:
   - File created  
   - File deleted  
   - File moved
3. Every change is logged into a file inside the share:  
   `changes.log`
4. A **systemd service** runs the script permanently and restarts automatically if it crashes.

This is a small but real-world monitoring solution that covers important Cloud and Linux concepts.

## Terraform Infrastructure:
This project will include a Terraform configuration that deploys:

- Resource Group
- Storage Account with File Share
- Linux Virtual Machine
- Network, NSGs, VNet
- Mounting configuration via cloud-init
- Script deployment and systemd setup

---


## 🧩 Part 1 — Creating and Mounting the Azure File Share

### 1. Install required package on Linux

The Azure File Share uses the **CIFS/SMB protocol**, so Linux needs `cifs-utils`:

```bash
sudo apt update
sudo apt install cifs-utils

```

## 🧩 Part 2 — Connecting to the VM via SSH Keys

###  1. SSH command

```bash
ssh -i /path/to/privatekey.pem username@public-ip

```

### 2. Fixing SSH key permissions

SSH refuses keys that are too open:
- Permissions 0664 ... are too open.


Fix:

```bash
chmod 600 /path/to/privatekey.pem
```

What this means:
600 = only the owner can read and write the file.
SSH requires this for security.

## 🧩 Part 3 — Understanding Linux Permissions Briefly

| Permission | Meaning                              |
|-----------|---------------------------------------|
| 6 (rw-)   | read + write                          |
| 0 (---)   | no access                             |
| 600       | owner can read/write; no one else can |
| 777       | everyone can read/write/execute       |


## 🧩 Part 4 — Why We Needed `sudo tee` Instead of `>` Redirect

When using:

```bash
sudo echo "hello" > file.txt
```
The redirect (>) happens before sudo, so the user (not root) tries writing → permission denied.

Correct way:
```bash
echo "hello" | sudo tee file.txt
```
**tee** receives root permissions and writes correctly.



## 🧩 Part 5 — The File Watcher Script

`inotifywait` is part of **inotify-tools**, a Linux feature to detect changes on files/folders.

### Install it:

```bash
sudo apt install inotify-tools
```

### Create the script:
*/home/brandon/Desktop/Engineering/linux/az-files-watcher.sh*

```bash
#!/bin/bash

WATCH_DIR="/media/az-linux-files"
LOG_FILE="$WATCH_DIR/changes.log"

inotifywait -m -e create -e delete -e moved_to -e moved_from "$WATCH_DIR" --format '%e %w%f' |
while read event fullpath; do
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $event $fullpath" | sudo tee -a "$LOG_FILE"
done
  ```

### Make it executable:

```bash
sudo chmod +x /home/brandon/Desktop/Engineering/linux/az-files-watcher.sh
```

## 🧩 Part 6 — Understanding systemd (VERY IMPORTANT)

**systemd** is the service manager on Linux. It controls:

- services
- background tasks
- startup programs
- logging
- dependencies
- crashes & restarts

A unit file (service file) describes how a service runs.

### Why do we need systemd?
Because scripts launched from the terminal:

- stop when logout
- stop after VM reboot
- stop after errors
- do not restart automatically
- do not log cleanly

We want the watcher script to run 24/7, so the **systemd** is perfect.

## 🧩 Part 7 — The systemd Service File

**Path:**  
`/etc/systemd/system/az-files-watcher.service`

```ini
[Unit]
Description=Azure File Share watcher (logs create/delete/move events)
After=network.target remote-fs.target

[Service]
Type=simple
ExecStart=/home/brandon/Desktop/Engineering/linux/az-files-watcher.sh
Restart=always
RestartSec=5
User=root
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=az-files-watcher

[Install]
WantedBy=multi-user.target
```

## 🧩 Part 8 — Enabling & Running the Service

### 1. Reload systemd
```bash
sudo systemctl daemon-reload
```

### 2. Enable autostart
```bash
sudo systemctl enable az-files-watcher.service
```

### 3. Start it
```bash
sudo systemctl start az-files-watcher.service
```

### 4. Check status
```bash
sudo systemctl status az-files-watcher.service
```

### 5. Check logs
```bash
journalctl -u az-files-watcher.service -f
```

### 6. Test
```bash
cd /media/az-linux-files
sudo touch testfile.txt
sudo rm testfile.txt
```

Check:
```bash
cat /media/az-linux-files/changes.log
``` 
