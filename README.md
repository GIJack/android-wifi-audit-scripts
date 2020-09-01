# android-wifi-audit-scripts
BASH scripts for performing various functions related to auditing 802.11*
security using android phones with patched firmware.


Requirements
------------
1. rooted phone, running some variant of android that supports bash. LineageOS
and Kali Nethunter which is based on Lineage have the upgraded toybox binary
which includes a pseudo-bash shell instead of just dash.
2. Nexmon https://github.com/seemoo-lab/nexmon -  Nexmon is firmware patches
that enable monitor and packet injection modes on certain broadcom chipsets.
Best support is the Google Nexus 5, the Nexus 6P. Nexus 5 has the best support
combine with the smallest size, best ergonomics and lightest weight is the
most portable.

WARNING - THESE CHIPSETS HAVE A KNOWN EXPLOIT IN THEM. DON'T USE AS A DAILY
DRIVER OR AS A COMMUNICATIONS DEVICE

Files
------

**phone_packages/**	- directory with pre-assembeled and tested packages
			  for specific phones along with an ADB install script
			  tested.

**bash_completion/**	- directory with bash completion scripts

**binaries/**		- directory with staticly compiled binaries for all
			  needed tools
**libraries/**		- precompiled libraries needed for capture


**wifi_capture.sh** - capture packets with tcpdump. files are saved to Downloads/
directory in Android. Named and datestamped subcommands are:

* ap_beacon	- captures 802.11 base station beacons
* ap_handshake	- captures 802.11 WPA/WPA2 handshakes
* all_by_mac	- captures all frames associated with MAC address specified
* all_by_name	- captures all frames associated with ESSID name
* custom	- use raw tcpdump syntax

* help		- show usage and commands
* test		- test if everything is setup correctly
* kill		- stop capture, write to files, reload android API for files,
		  and exit
  
**wifi_attack.sh** - run various 802.11 Wireless attacks. Front end for various
tools. Subcommands are:

* flood_auth	- Flood auth requests. If a parameter  is given it is assumed
		  to be the MAC address of the AP.(MDK3)
* confuse_wids	- Confuse a WIDS system. Needs an SSID as a parameter.(MDK3)
* tkip_shutdown	- Perform the "Michael Shutdown" exploit against a target AP.
		  AP must be using TKIP encryption. Needs an AP MAC address as a
		  second parameter.(MDK3) You can use "tkip_shutdown qos <MAC>"
		  to use the TKIP QoS exploit in conjunction.(MDK3)
* decloak	- Attempt to decloak an access point(get the SSID) that is
		  hidden. saves file to Download/ (MDK3)
* deauth	- De-auth clients from a specified AP. You must specify the MAC
		  address of the AP.(aireplay-ng)
* deauth-client	- De-auth specific client from AP. Specify AP and client such as:
		  deauth-client <AP MAC> <Client MAC>
		  
* reaver_wps	- Bruteforce target AP with reaver. need to specify AP MAC
		  address(ESSID). You may specify "pixie" as the second
		  parameter to use pixiewps to try a pixiedust attack.(reaver)
		  
* help		- This message
* test		- Test nexutil install
* kill		- Stop attack and exit


hijacker_actions
------------------
Saved actions for the "Hijacker" app for android. needs Nexmon and root. Allows
for custom actions with variables.

https://github.com/chrisk44/Hijacker

**hijacker_actions/** - directory with actions for using these scripts in the app

Connectbot
----------
Connectbot is an ssh and local terminal app that allows limited scripting and
automation.
https://github.com/connectbot/connectbot

**connectbot/** - directory with a connectbot connection database preconfigured
to run our scripts on local terminal.

