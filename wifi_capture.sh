#!/system/xbin/bash
#
# Run this on android with nexmon to capture and save packets for a file
#
# Needs nexutil, tcpdump and bash working
# exit codes 0 success, 1 program fail, 2 help, 4 misconfiguration, 8 undefined
# unknown bug.

### CONFIG ###
save_loc=/storage/emulated/0/Download/
capfile_base="wifi_cap"
iface=wlan0
tcpdump_options=""
pid_file="/data/local/tmp/wifi_capture.pid"
### /CONFIG ###

tool=""
tool_options=""
export LD_PRELOAD=libnexmon.so
#date_stamp=$(date +%Y%m%d_%H%M%S)
date_stamp=$(date +%Y%m%d)
cap_file="${capfile_base}_${date_stamp}.pcap"
declare -i exit_code=0

help_and_exit(){
  cat 1>&2 << EOF
wifi_capture.sh: Automated android/nexmon capture script.

We are going to asssume you already have nexmon installed and working. If not:
Get that done first: https://github.com/seemoo-lab/nexmon

We also assume you already have tcpdump installed.

This script is designed to be the backend to a push button to capture packets.
Capture will continue until this script is given sigterm and then it will clean
up and exit, leaving the capture file in Download/

	Commands
Capture:
	<default>		No options, captures all packets

	ap_beacon		Captures 802.11 Beacons, needs a second
				parameter as BSSID, MAC of AP.(tcpdump)

	ap_handshake		Captures WPA handshakes, needs a second
				parameter as BSSID, MAC of AP.(tcpdump)

	all_by_mac		Captures all frames assoicated with BSSID MAC
				Address, as specified in second parameter
				(airodump-ng)

	all_by_name		Captures all frames associated with ESSID Access
				Point Name. Name specified as second parameter.
				(airmodump-ng)

	custom			Capture packets using specified tcpdump syntax.
				(tcpdump)

Script:
	help			This message

	test			Test nexutil install

	kill			Stop capture and exit

EOF
  exit 2
}

android_media_rescan(){
  # This is a media re-scan so the file shows up over MTP
  am broadcast -a android.intent.action.MEDIA_MOUNTED -d file:///${save_loc}
}

test_install(){
  local bin_needed="tcpdump nexutil airodump-ng"
  local lib_needed="libnexmon.so"
  local -i test_exit=0
  for file in ${bin_needed};do
    which ${file} &> /dev/null
    if [ ${?} -ne 0 ];then
      test_exit=1
      echo "${file} is not an executable, script won't run without it"
    fi
  done

  for file in ${lib_needed};do
    if [ ! -f "/system/lib/${file}" ];then
      echo "Cannot find Library ${file}, script will not run without it."
      test_exit=1
    fi
    ## 64 bit only
    #if [ ! -f "/system/lib64/${file}" ];then
    #  echo "Cannot find 64-bit Library ${file}, script will not run without it."
    #  test_exit=1
    #fi
  done

  [ ${test_exit} -eq 0 ] && echo "prereqs look fine, script should run"
  exit ${test_exit}
}


cleanup_and_exit(){
  if [ -f ${pid_file} ];then
    local kill_pid=$(cat ${pid_file})
    kill ${kill_pid}
    rm -f ${pid_file}
   else
    echo "no pidfile"
    killall -s SIGTERM $(basename $0)
  fi
  # This is a media re-scan so the file shows up over MTP
  android_media_rescan
  #turn monitor mode off
  nexutil -m0
  nexutil -p0
  exit
}

main() {
  trap cleanup_and_exit SIGTERM SIGINT

  local command="${1}"
  local param="${@:2}"
  local -i pid=0

  case ${command} in
   help|--help|-\?)
    help_and_exit
    ;;
   kill)
    cleanup_and_exit
    ;;
   test)
    test_install
    ;;
   ap_beacon)
    tool="tcpdump"
    tool_options="type mgt subtype beacon"
    [ ! -z ${param} ] && tcpdump_options+=" and ether src ${param}"
    ;;
   ap_handshake)
    tool="tcpdump"
    tool_options="ether proto 0x888e"
    [ ! -z ${param} ] && tcpdump_options+=" and ether host ${param}"
    ;;
   all_by_mac)
    tool="airodump"
    [ -z ${param} ] && exit_with_error 4 "No MAC specified"
    tool_options+=" --bssid ${param}"
    ;;
   all_by_name)
    tool="airodump"
    [ -z ${param} ] && exit_with_error 4 "No Name specified"
    tool_options+=" --essid ${param}"
    ;;
   custom)
    tool="tcpdump"
    tool_options="${param}"
    ;;
   *)
    tool="tcpdump"
    ;;
  esac

  [ $UID -ne 0 ] && (echo "Got Root?";exit 2)

  #set monitor mode on
  nexutil -m2
  nexutil -p1

  local -i cap_file_i=0
  while [ -f $"${save_loc}/${cap_file}" ];do
    cap_file="${capfile_base}_${date_stamp}_${cap_file_i}.pcap"
    cap_file_i+=1
  done

  case ${tool} in
   tcpdump)
    tcpdump -i ${iface} ${tool_options} -w "${save_loc}/${cap_file}" &
    pid=$!
    ;;
   airodump)
    airodump-ng --output-format pcap --write "${save_loc}/${cap_file}" ${tool_options} ${iface} &
    pid=$!
    ;;
   *)
    exit_with_error 8 "No tool specified, this shouldn't happen, debug script!"
    ;;
  esac

    echo ${pid} > ${pid_file}
    wait ${pid}
  
  # This is a media re-scan so the file shows up over MTP
  android_media_rescan

  # turn off monitor mode
  nexutil -m0
  nexutil -p0

  # This should never get to this point. If so, it is a FAIL
  exit 8
}

main "${@}"
