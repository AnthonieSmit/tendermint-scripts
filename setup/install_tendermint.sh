#! /usr/bin/env bash

# Test if JQ is present.
which jq &> /dev/null || {
  echo "ERROR: This script requires jq. Please install jq first."
  exit 1
}

CONFIGFILE="settings.json"
APP_NAME="$(jq -r '.app.name' $CONFIGFILE)"
APP_VERSION="$(jq -r '.app.version' $CONFIGFILE)"

MONIKER="$(jq -r '.validator.moniker' $CONFIGFILE)"

function print_logo() {
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


DISCLAIMER: This script comes free as it is. There is no warranty
nor refunds possible. The script assumes that you are running
on a vanilla installation of Ubuntu Linux 20.04 LTS.

Usage is on your own risk!


EOF
}

function print_menu() {
clear

print_logo

COUNTER=0
echo "[ Available Chains ]"
for CHAIN in $(jq -r '.chains[].name' $CONFIGFILE)
do
  ALIAS=$(jq -r ".chains[$COUNTER].alias" $CONFIGFILE)
  echo "  $COUNTER) $ALIAS"
  COUNTER=$((COUNTER + 1))
done
echo ""
}

# Ensure that we are running as root.
if [ "$(whoami)" != "root" ]
then
  echo "ERROR: This script must be run as user root."
  exit 1
fi

MESSAGE="Select a chain or press CRTL+C to abort: "
ID=""
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
  echo -e "\nERROR: Your CPU architecture is not supported by this chain."
  exit 1
else
  echo -e "\nStarting installation."
fi

# Ensure group is present.
if grep "^$C_GROUP" /etc/group &> /dev/null
then
  echo "   Group $C_GROUP is present."
else
  echo "   Creating group $C_GROUP."
  groupadd -g "$C_GID" "$C_GROUP"
fi

# Ensure user is present.
if grep "^$C_USER" /etc/passwd &> /dev/null
then
  echo "   User $C_USER is present."
else
  echo "   Creating user $C_USER."
  useradd -g "$C_GID" -u "$C_UID" -d "$C_HOME" -m -s /bin/bash "$C_USER"
  # Add the user to systemd-journal so he can read logs.
  usermod -G "$C_GROUP,systemd-journal"
fi

# Ensure home directory is present.
if [ -d "$C_HOME" ]
then
  echo "   Home directory $C_HOME is present."
else
  echo "   Creating home directory $C_HOME."
  mkdir -m 0700 "$C_HOME"
  chown "$C_USER." "$C_HOME"
fi

# Ensure user profile is present.
for F in .bash_logout .bashrc .profile
do
  if [ ! -f "$C_HOME/$F" ]
  then
    echo "   Creating $C_HOME/$F"
    cp "/etc/skel/$F" "$C_HOME/"
    chown "$C_USER." "$C_HOME/$F"
  fi
done

# Ensure home directory is restricted.
if [ "$(stat -c %a $C_HOME)" == "700" ]
then
  echo "   Home directory $C_HOME is restricted."
else
  echo "   Restricting home directory $C_HOME."
  chmod 0700 "$C_HOME"
fi

# Ensure bin directory is present.
if [ -d "$C_HOME/bin" ]
then
  echo "   Directory $C_HOME/bin is present."
else
  echo "   Creating directory $C_HOME/bin."
  mkdir "$C_HOME/bin"
  chown "$C_USER." "$C_HOME/bin"
fi

# Ensure that log script is present.
if [ -f "$C_HOME/bin/logs" ]
then
  echo "   Log script is present."
else
  echo "   Creating log script."
  cat <<EOF > "$C_HOME/bin/logs"
#! /usr/bin/env bash

# Tail journalctl logs for the current user.
echo "Displaying logs. Press CTRL+C to quit."
journalctl -f
EOF
  chown "$C_USER." "$C_HOME/bin/logs"
  chmod 0755 "$C_HOME/bin/logs"
fi

# Ensure that indexed log script is present.
if [ -f "$C_HOME/bin/logs-indexed" ]
then
  echo "   Indexed log script is present."
else
  echo "   Creating indexed log script."
  cat <<EOF > "$C_HOME/bin/logs-indexed"
#! /usr/bin/env bash

# Tail journalctl logs for the current user.
echo "Displaying logs. Press CTRL+C to quit."
journalctl -f | grep indexed
EOF
  chown "$C_USER." "$C_HOME/bin/logs-indexed"
  chmod 0755 "$C_HOME/bin/logs-indexed"
fi

# Ensure that unslash script is present.
if [ -f "$C_HOME/bin/unslash" ]
then
  echo "   Unslash script is present."
else
  echo "   Creating unslash script."
  cat <<EOF > "$C_HOME/bin/unslash"
#! /usr/bin/env bash
$C_HOME/bin/$C_BINARY tx slashing unjail \
    --from $MONIKER \
    --yes \
    --chain-id $C_CHAIN_ID
EOF
  chown "$C_USER." "$C_HOME/bin/unslash"
  chmod 0755 "$C_HOME/bin/unslash"
fi

# Ensure that show-node-id script is present.
if [ -f "$C_HOME/bin/show-node-id" ]
then
  echo "   show-node-id script is present."
else
  echo "   Creating show-node-id script."
  cat <<EOF > "$C_HOME/bin/show-node-id"
#! /usr/bin/env bash
$C_HOME/bin/$C_BINARY tendermint show-node-id
EOF
  chown "$C_USER." "$C_HOME/bin/show-node-id"
  chmod 0755 "$C_HOME/bin/show-node-id"
fi

# Ensure staging directory is present.
if [ -d "$C_HOME/staging" ]
then
  echo "   Directory $C_HOME/staging is present."
else
  echo "   Creating directory $C_HOME/staging."
  mkdir "$C_HOME/staging"
  chown "$C_USER." "$C_HOME/staging"
fi

# Ensure that the package is present.
if [ -f "$C_HOME/staging/$(basename $C_URL)" ]
then
  echo "   Package $(basename $C_URL) is present."
else
  echo "   Downloading package $(basename $C_URL)."
  wget "$C_URL" -O "$C_HOME/staging/$(basename $C_URL)" &> /dev/null
  chown "$C_USER." "$C_HOME/staging/$(basename $C_URL)"
fi

# Ensure that the package is extracted.
if [ -f "$C_HOME/bin/$C_BINARY" ]
then
  echo "   $C_ALIAS package is present."
else
  echo "   Extracting $C_ALIAS."
  tar -xf "$C_HOME/staging/$(basename $C_URL)" -C "$C_HOME/bin"
  chown "$C_USER." "$C_HOME/bin/$C_BINARY"
fi

# Ensure that the service file is present.
if [ -f "/lib/systemd/system/$C_SERVICE.service" ]
then
  echo "   Service file is present."
else
  echo "   Creating service file."
cat <<EOF > "/lib/systemd/system/$C_SERVICE.service"
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

  echo "   Informing Systemd."
  systemctl daemon-reload
fi

# Ensure that the node has been initiated.
if [ -d "$C_HOME/$C_WORKDIR" ]
then
  echo "   Node has been initialized."
else
  echo "   Initializing node."
  runuser -u "$C_USER" -- $C_HOME/bin/$C_BINARY init $MONIKER --chain-id $C_CHAIN_ID &> /dev/null
  echo "   Updating genesis.json"
  wget "$C_GENESIS" -O "$C_HOME/$C_WORKDIR/config/genesis.json" &> /dev/null
  chown "$C_USER." "$C_HOME/$C_WORKDIR/config/genesis.json"
fi

# Ensuring chain-id is set.
if [ "$(grep ^chain-id $C_HOME/$C_WORKDIR/config/client.toml)" != "chain-id = \"$C_CHAIN_ID\"" ]
then
  echo "   Setting chain-id to $C_CHAIN_ID."
  sed -i -e "s/^chain-id.*/chain-id = \"$C_CHAIN_ID\"/" $C_HOME/$C_WORKDIR/config/client.toml
else
  echo "   Chain-id is set to $C_CHAIN_ID."
fi

# Ensuring keyring-backend is set to file.
if [ "$(grep ^keyring-backend $C_HOME/$C_WORKDIR/config/client.toml)" == 'keyring-backend = "os"' ]
then
  echo "   Setting keyring-backend to file."
  sed -i -e 's/^keyring-backend.*/keyring-backend = "file"/' $C_HOME/$C_WORKDIR/config/client.toml
else
  echo "   Keyring-backend is set to file."
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
  echo "   Seeds are configured."
else
  echo "   Setting seeds."
  sed -i -e "s/^seeds =.*/seeds = \"$SEEDS\"/" $C_HOME/$C_WORKDIR/config/config.toml
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
  echo "   Persistent peers are configured."
else
  echo "   Setting persistent peers."
  sed -i -e "s/^persistent_peers =.*/persistent_peers = \"$PERSISTENT_PEERS\"/" $C_HOME/$C_WORKDIR/config/config.toml
fi

# Ensure service is enabled.
if systemctl is-enabled $C_SERVICE &> /dev/null
then
  echo "   Service is enabled."
else
  echo "   Enabling service."
  systemctl enable $C_SERVICE
fi

# Ensure service is started.
if [ "$(systemctl status $C_SERVICE &> /dev/null; echo $?)" == "0" ]
then
  echo "   Service is started."
else
  echo "   Starting service."
  systemctl start $C_SERVICE
fi
