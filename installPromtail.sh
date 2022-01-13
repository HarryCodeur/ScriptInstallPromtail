#!/bin/bash                                                                     
##############################################################
#                       Techname
#                       06/01/2022
#                       Promtail Installation
##############################################################


##############################################################
#                       Function 
##############################################################
ME=$(basename "$0")
DATETIME=$(date "+%Y-%m-%d-%H-%M-%S")
INSTALL_LOG="/var/log/installPromtail"

function detect_operating_system() {
  echo_step "Detecting operating system"
  echo -e "\nuname" >>"$INSTALL_LOG"
  OPERATING_SYSTEM_TYPE=$(uname)
  export OPERATING_SYSTEM_TYPE
  if [ -f /etc/debian_version ]; then
    echo -e "\ntest -f /etc/debian_version" >>"$INSTALL_LOG"
    echo_step_info "Debian/Ubuntu"
    OPERATING_SYSTEM="DEBIAN"
  elif [ -f /etc/redhat-release ] || [ -f /etc/system-release-cpe ]; then
    echo -e "\ntest -f /etc/redhat-release || test -f /etc/system-release-cpe" >>"$INSTALL_LOG"
    echo_step_info "Red Hat / Fedora / CentOS"
    OPERATING_SYSTEM="REDHAT"
  else
    {
      echo -e "\ntest -f /etc/debian_version"
      echo -e "\ntest -f /etc/redhat-release || test -f /etc/system-release-cpe"

    } >>"$INSTALL_LOG"
    exit_with_failure "Unsupported operating system"
  fi
  echo_success
  export OPERATING_SYSTEM
}

function detect_architecture() {
  echo_step "Detecting architecture"
  echo -e "\nuname -m" >>"$INSTALL_LOG"
  ARCHITECTURE=$(uname -m)
  export ARCHITECTURE
  echo_step_info "$ARCHITECTURE"
  echo_success
}

function detect_installer() {
  echo_step "Checking installation tools"
  case $OPERATING_SYSTEM in
    DEBIAN)
      if command_exists apt-get; then
        echo -e "\napt-get found" >>"$INSTALL_LOG"
        export MY_INSTALLER="apt"
        export MY_INSTALL="-qq install"
      else
        exit_with_failure "Command 'apt-get' not found"
      fi
      ;;
    REDHAT)
      # https://fedoraproject.org/wiki/Dnf
      if command_exists dnf; then
        echo -e "\ndnf found" >>"$INSTALL_LOG"
        export MY_INSTALLER="dnf"
        export MY_INSTALL="-y install"
      # https://fedoraproject.org/wiki/Yum
      # As of Fedora 22, yum has been replaced with dnf.
      elif command_exists yum; then
        echo -e "\nyum found" >>"$INSTALL_LOG"
        export MY_INSTALLER="yum"
        export MY_INSTALL="-y install"
      else
        exit_with_failure "Either 'dnf' or 'yum' are needed"
      fi
      # RPM
      if command_exists rpm; then
        echo -e "\nrpm found" >>"$INSTALL_LOG"
      else
        exit_with_failure "Command 'rpm' not found"
      fi
      ;;
  esac
  echo_success
}

function set_install_log() {
  if [[ ! $INSTALL_LOG ]]; then 
    # Termux
    if [ -d "$PREFIX/tmp" ]; then
      export INSTALL_LOG="$PREFIX/tmp/install_$DATETIME.log"
    # Normal
    else
      export INSTALL_LOG="/tmp/install_$DATETIME.log"
    fi
  fi
  if [ -e "$INSTALL_LOG" ]; then
    exit_with_failure "$INSTALL_LOG already exists"
  fi
}

function command_exists() {
  command -v "$1" >/dev/null 2>&1
}

function exit_with_failure() {
  echo_step "FAILURE: $1"
  echo_failure
}

######################## echo ################################
function echo_right() {
  TEXT=$1
  echo
  tput cuu1
  tput cuf "$(tput cols)"
  tput cub ${#TEXT}
  echo "$TEXT"
}

function echo_success() {
  tput setaf 2 0 0 # 2 = green
  echo_right "[ OK ]"
  tput sgr0  # reset terminal
}

function echo_failure() {
  tput setaf 1 0 0 # 1 = red
  echo_right "[ FAILED ]"
  tput sgr0  # reset terminal
}

function echo_warning() {
  tput setaf 3 0 0 # 3 = yellow
  echo_right "[ WARNING ]"
  tput sgr0  # reset terminal
  echo "    ($1)"
}

function echo_step() {
  tput setaf 6 0 0 # 6 = cyan
  echo -n "$1"
  tput sgr0  # reset terminal
}

# echo_step_info() outputs additional step info in cyan, without a newline.
function echo_step_info() {
  tput setaf 6 0 0 # 6 = cyan
  echo -n " ($1)"
  tput sgr0  # reset terminal
}

function echo_title() {
  TITLE=$1
  NCOLS=$(tput cols)
  NEQUALS=$(((NCOLS-${#TITLE})/2-1))
  tput setaf 3 0 0 # 3 = yellow
  echo_equals "$NEQUALS"
  printf " %s " "$TITLE"
  echo_equals "$NEQUALS"
  tput sgr0  # reset terminal
  echo
}

function echo_equals() {
  COUNTER=0
  while [  $COUNTER -lt "$1" ]; do
    printf '='
    (( COUNTER=COUNTER+1 ))
  done
}

######################## check ############################
function check_update() {
  echo_step "Check updates"
    case $MY_INSTALLER in
    apt)
      $MY_INSTALLER update >>"$INSTALL_LOG" &> /dev/null
      if [ "$?" -ne 0 ]; then
        exit_with_failure "Failed to do $MY_INSTALLER update"
      fi
      ;;
    dnf|yum)
      echo "N" | $MY_INSTALLER -y update >>"$INSTALL_LOG" &> /dev/null
      echo 
      if [ "$?" -ne 0 ]; then
        exit_with_failure "Failed to do $MY_INSTALLER update"
      fi
      ;;
  esac
  echo_success
}

function check_bash() {
  echo_step "Checking if current shell is bash"
  if [[ "$0" == *"bash" ]]; then
    exit_with_failure "Failed, your current shell is $0"
  fi
  echo_success
}

 function check_root() {
   test=`whoami`
if [ $test != "root" ]; then
  exit_with_failure "Script needs to be executed in root "
  exit 
fi
 }

######################## packages ############################

#Lsite des paquets
function check_list_packages(){
  check_packages vim
  check_packages unzip
  check_packages curl
}

#Installation
function check_packages() {
logiciel=$1
if ! $logiciel --version &>/dev/null ; then
  if ! $logiciel -version &>/dev/null ; then
    echo_step "Installation of $logiciel"
    $MY_INSTALLER $MY_INSTALL $logiciel -y &>/dev/null
    echo_success
  sleep 5
  fi
else
   echo_step "$logiciel is already installed"
   echo_success
fi
}

function curl_promtail() {
echo_step "Installation of the service"
curl -s 'https://api.github.com/repos/grafana/loki/releases/latest' | grep browser_download_url |  cut -d '"' -f 4 | grep promtail-linux-amd64.zip | wget -i - &> /dev/null
unzip promtail-linux-amd64.zip &> /dev/null
mv promtail-linux-amd64 /usr/local/bin/promtail &> /dev/null
mkdir -p /var/spool/promtail &> /dev/null
rm -R /etc/promtail-local-config.yaml &> /dev/null

tee -a /etc/promtail-local-config.yaml &> /dev/null <<EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /var/spool/promtail/positions.yaml

clients:
  - url: http://$IPServer:3100/loki/api/v1/push

#Systemd

#Systemd

scrape_configs:
 - job_name: journal
   journal:
     labels:
       cluster: $GroupSelect
       hostname: $HOSTNAME
       job: systemd-journal
   relabel_configs:
     - source_labels: ['__journal__systemd_unit']
       target_label: 'unit'

#$GroupSelect

 - job_name: system
   static_configs:
   - targets:
       - localhost
     labels:
       cluster: $GroupSelect
       hostname: $HOSTNAME
       job: varlogs
       __path__: /var/log/*log
       
EOF
echo_success
}

function create_service() {
echo_step "Create service"
rm -R /etc/systemd/system/promtail.service &>/dev/null
tee /etc/systemd/system/promtail.service &> /dev/null <<EOF
[Unit]
Description=Promtail service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/promtail -config.file /etc/promtail-local-config.yaml

[Install]
WantedBy=multi-user.target
EOF
echo_success
}

function remove_script() {
echo_step "Remove script"
rm -- "$0"
echo_success
}

function starting_service() {
echo_step "Starting service"
systemctl daemon-reload
systemctl start promtail.service
systemctl enable promtail.service &>/dev/null
echo_success
}

function modify_systemd_journald() {
echo_step "modify_systemd_journald"
echo 'ForwardToSyslog=yes' >> /etc/systemd/journald.conf
echo 'MaxLevelSyslog=debug' >> /etc/systemd/journald.conf
echo_success
}


##############################################################
#                           Main
##############################################################
echo
echo -e "\e[0;1m[\e[91;1mWARNING\e[0;1m] Please, before running the script, make an \e[91;1mupdate\e[0;1m of your system\e[0m"
echo
echo
echo -e "\e[34;1mRun the script ? \e[0m[\e[92;1mY\e[0m/\e[91;1mn\e[0m]\e[0m"
read Choice
case $Choice in
  y|Y|yes|YES|Yes|"") 
     ;;
  n|N|NO|No|no|*) echo -e "\e[31;1mInstallation cancelled\e[0m"
  exit 
     ;;
esac
echo

echo -e "\e[34;1mEnter an ip address other than 127.0.0.1 ? \e[0m[\e[91;1mN\e[0m/\e[92;1my\e[0m]\e[0m"
read ChoiceIPServer
case $ChoiceIPServer in
  n|N|NO|No|no|"") 
     IPServer="127.0.0.1"
     export IPServer
     ;;
  y|Y|yes|YES|Yes|*) echo -e "\e[31;1mPlease enter ip address\e[0m"
      read IPServer 
     ;;
esac
echo

echo -e "\e[34;1mPlease, enter cluster name (1 for Prod, 2 for Dev)\e[0m"

read ChoiceGroup
case $ChoiceGroup in
  1)
     GroupSelect="Prod"
     export GroupSelect
     ;;
  2)
     GroupSelect="Dev"
     export GroupSelect
     ;;
esac

echo
echo
echo_title "Check Prerequisites"
detect_operating_system
detect_architecture
detect_installer
check_update
check_root
check_bash

echo_title "Installation of packages"
check_list_packages

echo_title "Promtail configuration"
curl_promtail
create_service
remove_script
starting_service

echo_title "Done"
echo
echo
exit
