#! /usr/bin/env bash

function print() {
  # This function prints text to the screen with a little indentation.
  echo -e "   $@"
}

function error() {
  # This function prints an error message and exits the script.
  echo -e "\nERROR: $@"
  exit 1
}

function ensure_filemode() {
  # This function checks if a filemode is set correctly. It updates the
  # filemode when needed.
  FILE="$1"
  MODE="$2"

  if [ "$(stat -c %a $FILE)" != "$MODE" ]
  then
    print "Changing $FILE to mode $MODE."
    chmod "$MODE" "$FILE"
  fi
}

function ensure_fileowner() {
  # This function checks if a fileowner is set correctly. It updates the
  # fileowner when needed. Please note that this function ignores the group.
  FILE="$1"

  if [ "$(stat -c %U $FILE)" != "$C_USER" ]
  then
    print "Setting ownership for $FILE."
    chown "$C_USER." "$FILE"
  fi
}

# Ensure that we are running as root.
if [ "$(whoami)" != "root" ]
then
  error "This script must be run as user root."
fi

# Test if JQ is present.
which jq &> /dev/null || {
  print "Attempting to install jq."
  apt install --yes jq &> /dev/null
  if [ "$?" != "0" ]
  then
    error "JQ is required for this script but the installation failed.\nPlease install jq and try again."
  fi
}

# Set the location of the configuration file.
CONFIGFILE="settings.json"

# Get information about this app.
APP_NAME="$(jq -r '.app.name' $CONFIGFILE)"
APP_VERSION="$(jq -r '.app.version' $CONFIGFILE)"

# Do not restart the service by default.
RESTART_SERVICE=0

# Get generic information.
AMOUNT="$(jq -r '.validator.amount' $CONFIGFILE)"
COMMISSION_MAX_CHANGE_RATE="$(jq -r '.validator.commission_max_change_rate' $CONFIGFILE)"
COMMISSION_MAX_RATE="$(jq -r '.validator.commission_max_rate' $CONFIGFILE)"
COMMISSION_RATE="$(jq -r '.validator.commission_rate' $CONFIGFILE)"
DETAILS="$(jq -r '.validator.details' $CONFIGFILE)"
FEES="$(jq -r '.validator.fees' $CONFIGFILE)"
KEYNAME="$(jq -r '.validator.keyname' $CONFIGFILE)"
MONIKER="$(jq -r '.validator.moniker' $CONFIGFILE)"
SECURITY_CONTACT="$(jq -r '.validator.security_contact' $CONFIGFILE)"
WEBSITE="$(jq -r '.validator.website' $CONFIGFILE)"


function print_logo() {
  # This function prints a pretty logo and a disclaimer.
  cat << EOF



                                   %@#
                               *@@@@@@@@@,
                             @@@@@    .@@@@&
                           @@@@*         (@@@@
                         %@@@*             #@@@/
                        @@@@                 @@@@
                       @@@@                   @@@%
                      @@@@                     @@@,
                      @@@,  ,#@@@@@@@@@@@@@/.  (@@@
                      ,@@@@@@@@@&#(//((%@@@@@@@,@@@
                   &@@@@@/                    .,@@@ @#
                @@@@@/ @@.     ,@@@@@@@@@      /@@@ @@@@,
              @@@@%   @@@%    @@@@    /@@@.    @@@#   @@@@(
            %@@@#      @@@(   @@@(     @@@#   @@@@      @@@@.
           @@@@        .@@@#   @@@@@@@@@@%   @@@@        .@@@#
          @@@%           @@@@    ,@@@@&    ,@@@%           @@@&
         &@@@             ,@@@@          .@@@@              @@@/
         @@@                *@@@@/     #@@@@.               (@@@
        &@@&                   &@@@@& ,@@%                   @@@
        @@@@@@@*              /@& #@@@@@@@%             /@@@@@@@
            %@@@@@@@@@@@@@@@@@@@@#     #@@@@@@@@@@@@@@@@@@@%


$APP_NAME $APP_VERSION.

Created by Anthonie Smit 03-2022

DISCLAIMER: This script comes free as it is. There is no warranty
nor refunds possible. The script assumes that you are running
on a vanilla installation of Ubuntu Linux 20.04 LTS.

Usage is on your own risk!

Donate to the developer if your like this software:
 BTC:   1JRB94g5LMrkhK6hLPXHiqkjVgBz7ppBVW
 FLUX:  t1a5RJWkrJ3V9AGgE6PHaeLbnJas69KZ3w8
 VDL:   vdl10s993kx6mxc5uj7zrhrs62ryf4723qecvs4lfl
 BTCZ:  t1c3MEHWr3fkM1cZScJbXeS5p3NvA4N2Btx


EOF
}

function print_menu() {
  # This function prints the menu.

  # Clear the terminal
  clear

  # Print the logo
  print_logo

  # Loop over the available chains and display them as menu options.
  COUNTER=0
  echo "[ Available Chains ]"
  for CHAIN in $(jq -r '.chains[].name' $CONFIGFILE)
  do
    ALIAS=$(jq -r ".chains[$COUNTER].alias" $CONFIGFILE)
    print "$COUNTER) $ALIAS"
    COUNTER=$((COUNTER + 1))
  done

  # Add an extra new line.
  echo ""
}

# Set the initial message that we display to the user.
MESSAGE="Select a chain or press CRTL+C to abort: "
ID=""

# Loop until the user has givin us valid input.
while [ -z "$ID" ]
do
  # Print the Menu.
  print_menu

  # Ask user what to do.
  read -p "$MESSAGE" USERINPUT

  # Ensure that the user gave a valid input.
  if [ $(jq -r ".chains[$USERINPUT].name" $CONFIGFILE) == "null" ]
  then
    MESSAGE="Input is not valid. Select a chain or press CTRL+C to abort: "
  else
    ID="$USERINPUT"
  fi
done

# Get configuration details.
C_NAME=$(jq -r ".chains[$ID].name" $CONFIGFILE)
C_ALIAS=$(jq -r ".chains[$ID].alias" $CONFIGFILE)
C_USER=$(jq -r ".chains[$ID].user" $CONFIGFILE)
C_GROUP=$(jq -r ".chains[$ID].group" $CONFIGFILE)
C_UID=$(jq -r ".chains[$ID].uid" $CONFIGFILE)
C_GID=$(jq -r ".chains[$ID].gid" $CONFIGFILE)
C_HOME=$(jq -r ".chains[$ID].home" $CONFIGFILE)
C_BINARY=$(jq -r ".chains[$ID].binary" $CONFIGFILE)
C_CHAIN_ID=$(jq -r ".chains[$ID].chain_id" $CONFIGFILE)
C_SERVICE=$(jq -r ".chains[$ID].service" $CONFIGFILE)
C_WORKDIR=$(jq -r ".chains[$ID].workdir" $CONFIGFILE)
C_URL=$(jq -r ".chains[$ID].url.$(uname -m)" $CONFIGFILE)
C_GENESIS=$(jq -r ".chains[$ID].genesis" $CONFIGFILE)
C_SEEDS=$(jq -r ".chains[$ID].seeds" $CONFIGFILE)
C_PERSISTENT_PEERS=$(jq -r ".chains[$ID].persistent_peers" $CONFIGFILE)

# Ensure that the URL for our platform is valid.
if [ "C_URL" == "null" ]
then
  error "Your CPU architecture is not supported by this chain."
else
  print "Starting installation."
fi

# Ensure group is present.
if grep "^$C_GROUP" /etc/group &> /dev/null
then
  print "Group $C_GROUP is present."
else
  print "Creating group $C_GROUP."
  groupadd -g "$C_GID" "$C_GROUP"
fi

# Ensure user is present.
if grep "^$C_USER" /etc/passwd &> /dev/null
then
  print "User $C_USER is present."
else
  print "Creating user $C_USER."
  useradd -g "$C_GID" -G "$C_GROUP,systemd-journal" -u "$C_UID" -d "$C_HOME" -m -s /bin/bash "$C_USER"
fi

# Ensure home directory is present.
if [ -d "$C_HOME" ]
then
  print "Home directory $C_HOME is present."
else
  print "Creating home directory $C_HOME."
  mkdir -m 0750 "$C_HOME"
fi

ensure_filemode "$C_HOME" 750
ensure_fileowner "$C_HOME"

# Ensure user profile is present.
for F in .bash_logout .bashrc .profile
do
  if [ ! -f "$C_HOME/$F" ]
  then
    print "Creating $C_HOME/$F"
    cp "/etc/skel/$F" "$C_HOME/"
  fi
  ensure_filemode "$C_HOME/$F" 644
  ensure_fileowner "$C_HOME/$F"
done

# Ensure home directory is restricted.
ensure_filemode "$C_HOME" 750

# Ensure bin directory is present.
if [ -d "$C_HOME/bin" ]
then
  print "Directory $C_HOME/bin is present."
else
  print "Creating directory $C_HOME/bin."
  mkdir -m 0750 "$C_HOME/bin"
fi

ensure_fileowner "$C_HOME/bin"
ensure_filemode "$C_HOME/bin" 750

function generate_log_script() {
  cat <<EOF
#! /usr/bin/env bash

# Tail journalctl logs for the current user.
echo "Displaying logs. Press CTRL+C to quit."
journalctl -f
EOF
}

# Ensure that log script is present.
if [ -f "$C_HOME/bin/logs" ]
then
  FILE_CHECKSUM=$(md5sum "$C_HOME/bin/logs" | cut -f1 -d' ')
  GEN_CHECKSUM=$(generate_log_script | md5sum | cut -f1 -d' ')

  # Test if file needs to be updated.
  if [ "$FILE_CHECKSUM" == "$GEN_CHECKSUM" ]
  then
    print "Log script is present."
  else
    print "Updating log script."
    generate_log_script > "$C_HOME/bin/logs"
  fi
else
  print "Creating log script."
  generate_log_script > "$C_HOME/bin/logs"
fi

ensure_fileowner "$C_HOME/bin/logs"
ensure_filemode "$C_HOME/bin/logs" 750

function generate_indexed_log_script() {
  cat <<EOF
#! /usr/bin/env bash

# Tail journalctl logs for the current user.
echo "Displaying logs. Press CTRL+C to quit."
journalctl -f | grep indexed
EOF
}

# Ensure that indexed log script is present.
if [ -f "$C_HOME/bin/logs-indexed" ]
then
  FILE_CHECKSUM=$(md5sum "$C_HOME/bin/logs-indexed" | cut -f1 -d' ')
  GEN_CHECKSUM=$(generate_indexed_log_script | md5sum | cut -f1 -d' ')

  # Test if file needs to be updated.
  if [ "$FILE_CHECKSUM" == "$GEN_CHECKSUM" ]
  then
    print "Indexed log script is present."
  else
    print "Updating indexed log script."
    generate_log_script > "$C_HOME/bin/logs-indexed"
  fi
else
  print "Creating indexed log script."
  generate_indexed_log_script > "$C_HOME/bin/logs-indexed"
fi

ensure_fileowner "$C_HOME/bin/logs-indexed"
ensure_filemode "$C_HOME/bin/logs-indexed" 750

function generate_unjail_script() {
  cat <<EOF
#! /usr/bin/env bash
$C_HOME/bin/$C_BINARY tx slashing unjail \
    --from $MONIKER \
    --yes \
    --chain-id $C_CHAIN_ID
EOF
}

# Ensure that unslash script is present.
if [ -f "$C_HOME/bin/unjail" ]
then
  FILE_CHECKSUM=$(md5sum "$C_HOME/bin/unjail" | cut -f1 -d' ')
  GEN_CHECKSUM=$(generate_unjail_script | md5sum | cut -f1 -d' ')

  # Test if file needs to be updated.
  if [ "$FILE_CHECKSUM" == "$GEN_CHECKSUM" ]
  then
    print "Unjail script is present."
  else
    print "Updating unjail script."
    generate_log_script > "$C_HOME/bin/unjail"
  fi
else
  print "Creating unjail script."
  generate_unjail_script > "$C_HOME/bin/unjail"
fi

ensure_fileowner "$C_HOME/bin/unjail"
ensure_filemode "$C_HOME/bin/unjail" 750

function generate_show_node_id_script() {
  cat <<EOF
#! /usr/bin/env bash
$C_HOME/bin/$C_BINARY tendermint show-node-id
EOF
}

# Ensure that show-node-id script is present.
if [ -f "$C_HOME/bin/show-node-id" ]
then
  FILE_CHECKSUM=$(md5sum "$C_HOME/bin/show-node-id" | cut -f1 -d' ')
  GEN_CHECKSUM=$(generate_show_node_id_script | md5sum | cut -f1 -d' ')

  # Test if file needs to be updated.
  if [ "$FILE_CHECKSUM" == "$GEN_CHECKSUM" ]
  then
    print "show-node-id script is present."
  else
    print "Updating show-node-id script."
    generate_log_script > "$C_HOME/bin/show-node-id"
  fi
else
  print "Creating show-node-id script."
  generate_show_node_id_script > "$C_HOME/bin/show-node-id"
fi

ensure_fileowner "$C_HOME/bin/show-node-id"
ensure_filemode "$C_HOME/bin/show-node-id" 750

# Ensure staging directory is present.
if [ -d "$C_HOME/staging" ]
then
  print "Directory $C_HOME/staging is present."
else
  print "Creating directory $C_HOME/staging."
  mkdir -m 0750 "$C_HOME/staging"
fi

ensure_fileowner "$C_HOME/staging"
ensure_filemode "$C_HOME/staging" 750

# Ensure that the package is present.
if [ -f "$C_HOME/staging/$(basename $C_URL)" ]
then
  print "Package $(basename $C_URL) is present."
else
  print "Downloading package $(basename $C_URL)."
  wget "$C_URL" -O "$C_HOME/staging/$(basename $C_URL)" &> /dev/null
fi

ensure_fileowner "$C_HOME/staging/$(basename $C_URL)"
ensure_filemode "$C_HOME/staging/$(basename $C_URL)" 640

# Ensure that the package is extracted.
if [ -f "$C_HOME/bin/$C_BINARY" ]
then
  print "$C_ALIAS package is present."
else
  print "Extracting $C_ALIAS."
  tar -xf "$C_HOME/staging/$(basename $C_URL)" -C "$C_HOME/bin"
fi

ensure_fileowner "$C_HOME/bin/$C_BINARY"
ensure_filemode "$C_HOME/bin/$C_BINARY" 750

function generate_service_file() {
  cat <<EOF
[Unit]
Description=Vidulum Validator
After=network.target

[Service]
Group=$C_GROUP
User=$C_USER
WorkingDirectory=$C_HOME
ExecStart=$C_HOME/bin/$C_BINARY start
Restart=on-failure
RestartSec=3
LimitNOFILE=8192

[Install]
WantedBy=multi-user.target
EOF
}

# Ensure that the service file is present.
if [ -f "/lib/systemd/system/$C_SERVICE.service" ]
then
  FILE_CHECKSUM=$(md5sum "/lib/systemd/system/$C_SERVICE.service" | cut -f1 -d' ')
  GEN_CHECKSUM=$(generate_service_file | md5sum | cut -f1 -d' ')

  # Test if file needs to be updated.
  if [ "$FILE_CHECKSUM" == "$GEN_CHECKSUM" ]
  then
    print "Service file is present."
  else
    print "Updating service file."
    generate_service_file > "/lib/systemd/system/$C_SERVICE.service"
    print "Notifying systemd."
    systemctl daemon-reload
    RESTART_SERVICE=1
  fi
else
  print "Creating service file."
  generate_service_file > "/lib/systemd/system/$C_SERVICE.service"
  print "Informing Systemd."
  systemctl daemon-reload
fi

# Ensure that the node has been initiated.
if [ -d "$C_HOME/$C_WORKDIR" ]
then
  print "Node has been initialized."
else
  print "Initializing node."
  runuser -u "$C_USER" -- $C_HOME/bin/$C_BINARY init $KEYNAME --chain-id $C_CHAIN_ID &> /dev/null
  print "Updating genesis.json"
  wget "$C_GENESIS" -O "$C_HOME/$C_WORKDIR/config/genesis.json" &> /dev/null
fi

ensure_fileowner "$C_HOME/$C_WORKDIR/config/genesis.json"

# Ensuring chain-id is set.
if [ "$(grep ^chain-id $C_HOME/$C_WORKDIR/config/client.toml)" != "chain-id = \"$C_CHAIN_ID\"" ]
then
  print "Setting chain-id to $C_CHAIN_ID."
  sed -i -e "s/^chain-id.*/chain-id = \"$C_CHAIN_ID\"/" $C_HOME/$C_WORKDIR/config/client.toml
else
  print "Chain-id is set to $C_CHAIN_ID."
fi

# Ensuring keyring-backend is set to file.
if [ "$(grep ^keyring-backend $C_HOME/$C_WORKDIR/config/client.toml)" == 'keyring-backend = "os"' ]
then
  print "Setting keyring-backend to file."
  sed -i -e 's/^keyring-backend.*/keyring-backend = "file"/' $C_HOME/$C_WORKDIR/config/client.toml
else
  print "Keyring-backend is set to file."
fi

# Generate a list of seeds.
SEEDS=""
for HOST in $(jq -r ".chains[$ID].seeds[]" $CONFIGFILE)
do
  if [ -z "$SEEDS" ]
  then
    SEEDS="$HOST"
  else
    SEEDS="$SEEDS,$HOST"
  fi
done

# Ensure seeds are set.
if [ "$(grep '^seeds =' $C_HOME/$C_WORKDIR/config/config.toml)" == "seeds = \"$SEEDS\"" ]
then
  print "Seeds are configured."
else
  print "Setting seeds."
  sed -i -e "s/^seeds =.*/seeds = \"$SEEDS\"/" $C_HOME/$C_WORKDIR/config/config.toml
  RESTART_SERVICE=1
fi

# Generate a list of persistent peers.
PERSISTENT_PEERS=""
for HOST in $(jq -r ".chains[$ID].persistent_peers[]" $CONFIGFILE)
do
  if [ -z "$PERSISTENT_PEERS" ]
  then
    PERSISTENT_PEERS="$HOST"
  else
    PERSISTENT_PEERS="$PERSISTENT_PEERS,$HOST"
  fi
done

# Ensure persistent peers are set.
if [ "$(grep '^persistent_peers =' $C_HOME/$C_WORKDIR/config/config.toml)" == "persistent_peers = \"$PERSISTENT_PEERS\"" ]
then
  print "Persistent peers are configured."
else
  print "Setting persistent peers."
  sed -i -e "s/^persistent_peers =.*/persistent_peers = \"$PERSISTENT_PEERS\"/" $C_HOME/$C_WORKDIR/config/config.toml
  RESTART_SERVICE=1
fi

# Ensure service is enabled.
if systemctl is-enabled $C_SERVICE &> /dev/null
then
  print "Service is enabled."
else
  print "Enabling service."
  systemctl enable $C_SERVICE
fi

# Ensure service is started.
if [ "$RESTART_SERVICE" == 0 ]
then
  if [ "$(systemctl status $C_SERVICE &> /dev/null; echo $?)" == "0" ]
  then
    print "Service is started."
  else
    print "Starting service."
    systemctl start $C_SERVICE
  fi
else
  print "Restarting service."
  systemctl restart $C_SERVICE
fi
