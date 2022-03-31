#! /usr/bin/env bash

function print() {
  # This function prints text to the screen with a little indentation.
  echo -e "   $@"
}

function error() {
  # This function prints an error message and exits the script.
  echo -e "\nERROR: $@\n"
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
MANAGED="This file is managed by $APP_NAME. Changed might get overwritten."

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

Donate to the developer if you like this software:
  BTC:   1JRB94g5LMrkhK6hLPXHiqkjVgBz7ppBVW
  FLUX:  t1a5RJWkrJ3V9AGgE6PHaeLbnJas69KZ3w8
  VDL:   vdl10s993kx6mxc5uj7zrhrs62ryf4723qecvs4lfl
  BTCZ:  t1c3MEHWr3fkM1cZScJbXeS5p3NvA4N2Btx


Join us on Discord: https://discord.gg/3pTBRdq9


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
MESSAGE="Select a chain or press CTRL+C to abort: "
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
C_DENOM=$(jq -r ".chains[$ID].denom" $CONFIGFILE)

# Check if there are extra profiles for the selected chain.
if [ $(jq -r ".chains[$ID].profiles[0].name" $CONFIGFILE) != "null" ]
then
  COUNTER=0
  echo -e "\n[ Available Profiles ]"
  for PROFILE in $(jq -r ".chains[$ID].profiles[].name" $CONFIGFILE)
  do
    ALIAS=$(jq -r ".chains[$ID].profiles[$COUNTER].alias" $CONFIGFILE)
    print "$COUNTER) $ALIAS"
    COUNTER=$((COUNTER + 1))
  done
  echo ""

  MESSAGE="Select a profile or press CTRL+C to abort: "
  read -p "$MESSAGE" USERINPUT

  if [ $(jq -r ".chains[$ID].profiles[$USERINPUT].name" $CONFIGFILE) == "null" ]
  then
    error "Invalid input. Please restart the script and try again."
  else
    PROFILE="$USERINPUT"
  fi
else
  PROFILE=""
fi

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
# $MANAGED

# Tail journalctl logs for the current user.
echo "Displaying logs. Press CTRL+C to quit."
journalctl -f
EOF
}

function generate_indexed_log_script() {
  cat <<EOF
#! /usr/bin/env bash
# $MANAGED

# Tail journalctl logs for the current user.
echo "Displaying logs. Press CTRL+C to quit."
journalctl -f | grep indexed
EOF
}

function generate_unjail_script() {
  cat <<EOF
#! /usr/bin/env bash
# $MANAGED

$C_HOME/bin/$C_BINARY tx slashing unjail \
    --from $MONIKER \
    --yes \
    --chain-id $C_CHAIN_ID
EOF
}

function generate_show_node_id_script() {
  cat <<EOF
#! /usr/bin/env bash
# $MANAGED

$C_HOME/bin/$C_BINARY tendermint show-node-id
EOF
}

function generate_create_wallet_script() {
  cat <<EOF
#! /usr/bin/env bash
# $MANAGED

$C_HOME/bin/$C_BINARY keys add $KEYNAME --keyring-backend file
EOF
}

function generate_create_validator_script() {
  cat <<EOF
#! /usr/bin/env bash
# $MANAGED

$C_HOME/bin/$C_BINARY tx staking create-validator \\
    --commission-max-change-rate "$COMMISSION_MAX_CHANGE_RATE" \\
    --commission-max-rate "$COMMISSION_MAX_RATE" \\
    --commission-rate "$COMMISSION_RATE" \\
    --amount ${AMOUNT}$DENOM \\
    --pubkey $($C_HOME/bin/$C_BINARY tendermint show-validator) \\
    --website "$WEBSITE" \\
    --details "$DETAILS" \\
    --security-contact "$SECURITY_CONTACT" \\
    --moniker "$MONIKER" \\
    --chain-id $C_CHAIN_ID \\
    --min-self-delegation "1000" \\
    --fees "${FEES}$C_DENOM" \\
    --from $KEYFILE \\
    --yes
EOF
}

function script_template() {
  SCRIPT="$1"
  GENERATE_FUNCTION="$2"

  if [ -f "$C_HOME/bin/$SCRIPT" ]
  then
    FILE_CHECKSUM=$(md5sum "$C_HOME/bin/$SCRIPT" | cut -f1 -d' ')
    GEN_CHECKSUM=$($GENERATE_FUNCTION | md5sum | cut -f1 -d' ')

    # Test if file needs to be updated.
    if [ "$FILE_CHECKSUM" == "$GEN_CHECKSUM" ]
    then
      print "Script $SCRIPT is present."
    else
      print "Updating script $SCRIPT."
      $GENERATE_FUNCTION > "$C_HOME/bin/$SCRIPT"
    fi
  else
    print "Creating script $SCRIPT."
    $GENERATE_FUNCTION > "$C_HOME/bin/$SCRIPT"
  fi

  ensure_fileowner "$C_HOME/bin/$SCRIPT"
  ensure_filemode "$C_HOME/bin/$SCRIPT" 750
}

script_template "create_validator" "generate_create_validator_script"
script_template "create_wallet" "generate_create_wallet_script"
script_template "logs" "generate_log_script"
script_template "logs-indexed" "generate_indexed_log_script"
script_template "show-node-id" "generate_show_node_id_script"
script_template "unjail" "generate_unjail_script"

function generate_list_wallet_script(){
  cat <<EOF
#! /usr/bin/env bash
# $MANAGED

$C_HOME/bin/$C_BINARY keys list
EOF
}

# Ensure that create_validator script is present.
if [ -f "$C_HOME/bin/list_wallet" ]
then
  FILE_CHECKSUM=$(md5sum "$C_HOME/bin/list_wallet" | cut -f1 -d' ')
  GEN_CHECKSUM=$(generate_list_wallet_script | md5sum | cut -f1 -d' ')

  # Test if file needs to be updated.
  if [ "$FILE_CHECKSUM" == "$GEN_CHECKSUM" ]
  then
    print "list_wallet script is present."
  else
    print "Updating list_wallet script."
    generate_list_wallet_script > "$C_HOME/bin/list_wallet"
  fi
else
  print "Creating list_wallet script."
  generate_list_wallet_script > "$C_HOME/bin/list_wallet"
fi

ensure_fileowner "$C_HOME/bin/list_wallet"
ensure_filemode "$C_HOME/bin/list_wallet" 750


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
# $MANAGED
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

# Test if an profile is available for this chain.
if [ -n "$PROFILE" ]
then
  PROFILE_ALIAS=$(jq -r ".chains[$ID].profiles[$PROFILE].alias" $CONFIGFILE)
  print "Processing profile $PROFILE_ALIAS"

  if [ "$(jq -r \".chains[$ID].profiles[$PROFILE].app\" $CONFIGFILE)" != "[]" ]
  then
    print "Processing options for app.toml"
    COUNTER=0
    ELEMENTS=$(jq ".chains[$ID].profiles[$PROFILE].app | length" $CONFIGFILE)
    while [ $COUNTER -lt $ELEMENTS ]
    do
      KEY=$(jq -r ".chains[$ID].profiles[$PROFILE].app[$COUNTER].key" $CONFIGFILE)
      VALUE=$(jq -r ".chains[$ID].profiles[$PROFILE].app[$COUNTER].value" $CONFIGFILE)
      TYPE=$(jq -r ".chains[$ID].profiles[$PROFILE].app[$COUNTER].type" $CONFIGFILE)
      if [ "$TYPE" == "null" ]
      then
	if [ "$(grep ^$KEY $C_HOME/$C_WORKDIR/config/app.toml)" != "$KEY = \"$VALUE\"" ]
	then
	  print "Setting $KEY to $VALUE"
	  sed -i -e "s/^$KEY =.*/$KEY = \"$VALUE\"/" $C_HOME/$C_WORKDIR/config/app.toml
	  RESTART_SERVICE=1
	fi
      else
	if [ "$(grep ^$KEY $C_HOME/$C_WORKDIR/config/app.toml)" != "$KEY = $VALUE" ]
        then
          print "Setting $KEY to $VALUE"
  	  sed -i -e "s/^$KEY =.*/$KEY = $VALUE/" $C_HOME/$C_WORKDIR/config/app.toml
	  RESTART_SERVICE=1
	fi
      fi
      COUNTER=$(expr $COUNTER + 1)
    done
  fi

  if [ "$(jq -r \".chains[$ID].profiles[$PROFILE].config\" $CONFIGFILE)" != "[]" ]
  then
    print "Processing options for config.toml"
    COUNTER=0
    ELEMENTS=$(jq ".chains[$ID].profiles[$PROFILE].config | length" $CONFIGFILE)
    while [ $COUNTER -lt $ELEMENTS ]
    do
      KEY=$(jq -r ".chains[$ID].profiles[$PROFILE].config[$COUNTER].key" $CONFIGFILE)
      VALUE=$(jq -r ".chains[$ID].profiles[$PROFILE].config[$COUNTER].value" $CONFIGFILE)
      TYPE=$(jq -r ".chains[$ID].profiles[$PROFILE].config[$COUNTER].type" $CONFIGFILE)
      if [ "$TYPE" == "null" ]
      then
	if [ "$(grep ^$KEY $C_HOME/$C_WORKDIR/config/config.toml)" != "$KEY = \"$VALUE\"" ]
        then
          print "Setting $KEY to $VALUE"
          sed -i -e "s/^$KEY =.*/$KEY = \"$VALUE\"/" $C_HOME/$C_WORKDIR/config/config.toml
	  RESTART_SERVICE=1
	fi
      else
	if [ "$(grep ^$KEY $C_HOME/$C_WORKDIR/config/config.toml)" != "$KEY = $VALUE" ]
        then
          print "Setting $KEY to $VALUE"
          sed -i -e "s/^$KEY =.*/$KEY = $VALUE/" $C_HOME/$C_WORKDIR/config/config.toml
	  RESTART_SERVICE=1
	fi
      fi
      COUNTER=$(expr $COUNTER + 1)
    done
  fi
fi

# Ensure service is enabled.
if systemctl is-enabled "$C_SERVICE" &> /dev/null
then
  print "Service is enabled."
else
  print "Enabling service."
  systemctl enable "$C_SERVICE"
fi

# Ensure service is started.
if [ "$RESTART_SERVICE" == 0 ]
then
  if [ "$(systemctl status $C_SERVICE &> /dev/null; echo $?)" == "0" ]
  then
    print "Service is started."
  else
    print "Starting service."
    systemctl start "$C_SERVICE"
  fi
else
  print "Restarting service."
  systemctl restart "$C_SERVICE"
fi

# Let the user know that we are done.
print "Installation completed successfully."
