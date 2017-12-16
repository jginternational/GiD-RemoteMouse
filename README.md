# GiD-RemoteMouse
This project connects your phone with GiD to zoom it, pan it, and rotate it

# Install
Open a command line with Admin powers! (windows -> run cmd as administrator, not powershell)
* mkdir GiD-RemoteMouse
* cd GiD-RemoteMouse
* git clone https://github.com/jginternational/GiD-RemoteMouse.git
* (windows) mklink /J "C:\Program Files\GiD\GiD 13.1.8d\scripts\gid_remote_control" .
* (linux)

# Run (in GiD command line)
* -np- SRC {gid_remote_control\web_server.tcl}
* -np- remotemouse_web_server_init
* go to -> http://localhost.com:14788