#!/bin/sh

#
# Initialise/configure TYPO3 Neos pre-installed during 'docker build'
# and located in /tmp/typo3-neos.tgz (@see install_typo3_neos() below)
#

set -e
set -u

#
# ENV variables passed to container. If they are not provided, defaults are set.
#
NEOS_APP_NAME=${NEOS_APP_NAME:="neos"}
NEOS_APP_DB_NAME=${NEOS_APP_DB_NAME:="typo3_neos"}
NEOS_APP_USER_NAME=${NEOS_APP_USER_NAME:="admin"}
NEOS_APP_USER_PASS=${NEOS_APP_USER_PASS:="password"}
NEOS_APP_USER_FNAME=${NEOS_APP_USER_FNAME:="Admin"}
NEOS_APP_USER_LNAME=${NEOS_APP_USER_LNAME:="User"}
NEOS_APP_VHOST_NAMES=${NEOS_APP_VHOST_NAMES:="${NEOS_APP_NAME} dev.${NEOS_APP_NAME} test.${NEOS_APP_NAME}"}
NEOS_APP_SITE_PACKAGE=${NEOS_APP_SITE_PACKAGE:="TYPO3.NeosDemoTypo3Org"}
NEOS_APP_FORCE_PULL=${NEOS_APP_FORCE_PULL:=false}
NEOS_APP_FORCE_SITE_REIMPORT=${NEOS_APP_FORCE_SITE_REIMPORT:=false}
TYPO3_NEOS_COMPOSER_PARAMS=${TYPO3_NEOS_COMPOSER_PARAMS:="--optimize-autoloader"}
#
# ENV variables (end)
#


# Other variables - do not change them
CWD=$(pwd) # Points to /tmp/build-typo3-neos/ where install scripts located
WEB_ROOT="/data/www"
NEOS_ROOT="${WEB_ROOT}/${NEOS_APP_NAME}"
SETTINGS_SOURCE_FILE="${CWD}/Settings.yaml"
VHOST_SOURCE_FILE="${CWD}/vhost.conf"
VHOST_FILE="/data/conf/nginx/hosts.d/${NEOS_APP_NAME}.conf"
DB_ENV_MARIADB_PASS=${DB_ENV_MARIADB_PASS:="password"}
DB_PORT_3306_TCP_ADDR=${DB_PORT_3306_TCP_ADDR:="127.0.0.1"}
DB_PORT_3306_TCP_PORT=${DB_PORT_3306_TCP_PORT:="3306"}
MYSQL_CMD_AUTH_PARAMS="--user=admin --password=$DB_ENV_MARIADB_PASS --host=$DB_PORT_3306_TCP_ADDR --port=$DB_PORT_3306_TCP_PORT"
NEOS_USER_BUILD_SCRIPT="build.sh" # Script which might be present in $NEOS_ROOT and will be called at the end of the setup process


#######################################
# Echo/log function
# Arguments:
#   String: value to log
#######################################
log() {
  echo "=> ${NEOS_APP_NAME^^} APP: $@" >&2
}

#########################################################
# Check in the loop (every 2s) if the database backend
# service is already available.
#########################################################
function wait_for_db() {
  set +e
  local RET=1
  while [[ RET -ne 0 ]]; do
    mysql $MYSQL_CMD_AUTH_PARAMS --execute "status" > /dev/null 2>&1
    RET=$?
    if [[ RET -ne 0 ]]; then
      log "Waiting for DB service..."
      sleep 2
    fi
  done
  set -e
  
  # Display DB status...
  mysql $MYSQL_CMD_AUTH_PARAMS --execute "status"
}

#########################################################
# Moves pre-installed in /tmp TYPO3 Neos to its
# its target location ($NEOS_ROOT), if it's not there yet
# Globals:
#   WEB_ROOT
#   NEOS_ROOT
#   NEOS_APP_NAME
#########################################################
function install_typo3_neos() {
  # Check if app is already installed (when restaring stopped container)
  if [ ! -d $NEOS_ROOT ]; then
    log "Installing TYPO3 Neos (from pre-installed archive)..."
    cd $WEB_ROOT && tar -zxf /tmp/typo3-neos.tgz
    mv typo3-neos $NEOS_APP_NAME
  fi

  log "Neos installed."
  cd $NEOS_ROOT
  git log -5 --pretty=format:"%h %an %cr: %s" --graph # Show most recent changes
  
  # If app is/was already installed, pull most recent code
  if [ "${NEOS_APP_FORCE_PULL^^}" = TRUE ]; then
    log "Resetting current working directory..."
    git status && git clean -f -d && git reset --hard # make the working dir clean
    log "Pulling the newest codebase..."
    git pull
    git log -10 --pretty=format:"%h %an %cr: %s" --graph
  fi
  
  # If composer.lock has changed, this will re-install things...
  composer install $TYPO3_NEOS_COMPOSER_PARAMS
}

#########################################################
# Creates Neos database, if doesn't exist yet
# Globals:
#   NEOS_APP_DB_NAME
#   MYSQL_CMD_AUTH_PARAMS
#########################################################
function create_app_db() {
  log "Creating Neos db '$NEOS_APP_DB_NAME' (if it doesn't exist yet)..."
  mysql $MYSQL_CMD_AUTH_PARAMS --execute="CREATE DATABASE IF NOT EXISTS $NEOS_APP_DB_NAME CHARACTER SET utf8 COLLATE utf8_general_ci"
  log "DB created."
}

#########################################################
# Create Nginx vhost, if it doesn't exist yet
# Globals:
#   NEOS_ROOT
#   VHOST_FILE
#   VHOST_SOURCE_FILE
# Arguments:
#   String: virtual host name(s), space separated
#########################################################
function create_vhost_conf() {
  local vhost_names=$@
  local vhost_names_arr=($vhost_names)
  log "Configuring vhost in ${VHOST_FILE} for vhost(s) ${vhost_names}"

  if [ ! -f $VHOST_FILE ]; then
    cat $VHOST_SOURCE_FILE > $VHOST_FILE
  fi

  sed -i -r "s#%server_name%#${vhost_names}#g" $VHOST_FILE
  sed -i -r "s#%root%#${NEOS_ROOT}#g" $VHOST_FILE
  
  # Configure redirect: www to non-www
  # @TODO: make it configurable via env var
  # @TODO: make possible reversed behaviour (non-www to www)
  sed -i -r "s#%server_name_primary%#${vhost_names_arr[0]}#g" $VHOST_FILE
  
  cat $VHOST_FILE
  log "Nginx vhost configured."
}

#########################################################
# Update Neos Settings.yaml with db backend settings
# Globals:
#   SETTINGS_SOURCE_FILE
#   NEOS_APP_DB_NAME
#   DB_ENV_MARIADB_PASS
#   DB_PORT_3306_TCP_ADDR
#   DB_PORT_3306_TCP_PORT
#########################################################
function create_settings_yaml() {
  local settings_file="Configuration/Settings.yaml"
  if [ ! -f $settings_file ]; then
    cat $SETTINGS_SOURCE_FILE > $settings_file
    log "Configuration file $settings_file created."
  fi

  log "Configuring $settings_file..."
  sed -i -r "1,/dbname:/s/dbname: .+?/dbname: $NEOS_APP_DB_NAME/g" $settings_file
  sed -i -r "1,/user:/s/user: .+?/user: admin/g" $settings_file
  sed -i -r "1,/password:/s/password: .+?/password: $DB_ENV_MARIADB_PASS/g" $settings_file
  sed -i -r "1,/host:/s/host: .+?/host: $DB_PORT_3306_TCP_ADDR/g" $settings_file
  sed -i -r "1,/port:/s/port: .+?/port: $DB_PORT_3306_TCP_PORT/g" $settings_file

  cat $settings_file
  log "$settings_file updated."
}

#########################################################
# Check latest Neos doctrine:migration status.
# Used to detect if this is fresh Neos installation
# or re-run from previous state.
#########################################################
function get_latest_db_migration() {
  log "Checking Neos db migration status..."
  local v=$(./flow doctrine:migrationstatus | grep -i 'Current Version' | awk '{print $4$5$6}')
  log "Last db migration: $v"
  echo $v
}

#########################################################
# Do Neos doctrine:migrate
#########################################################
function doctrine_update() {
  log "Doing doctrine:migrate..."
  ./flow doctrine:migrate --quiet
  log "Finished doctrine:migrate."
}

#########################################################
# Create admin user
#########################################################
function create_admin_user() {
  log "Creating admin user..."
  ./flow user:create --roles Administrator $NEOS_APP_USER_NAME $NEOS_APP_USER_PASS $NEOS_APP_USER_FNAME $NEOS_APP_USER_LNAME
}

#########################################################
# Install site package
# Arguments:
#   String: site package name to install
#########################################################
function install_site_package() {
  local site_package_name=$@
  log "Installing $site_package_name site package..."
  ./flow site:import --packageKey $site_package_name
}

#########################################################
# Prune all site data.
# Used when re-importing the site package.
#########################################################
function prune_site_package() {
  log "Pruning old site..."
  ./flow site:prune --confirmation
  log "Done."
}

#########################################################
# Warm up Flow caches for specified FLOW_CONTEXT
# Arguments:
#   String: FLOW_CONTEXT value, eg. Development, Production
#########################################################
function warmup_cache() {
  FLOW_CONTEXT=$@ ./flow flow:cache:flush --force;
  FLOW_CONTEXT=$@ ./flow cache:warmup;
}

#########################################################
# Set correct permission for Neos app
#########################################################
function set_permissions() {
  chown -R www:www $NEOS_ROOT
}

#########################################################
# If the installed TYPO3 Neos distribution contains
# executable ./build.sh file, it will run it.
# This script should do all necessary steps to make
# the site up&running, e.g. compile CSS.
#########################################################
function user_build_script() {
  cd $NEOS_ROOT;
  if [[ -x $NEOS_USER_BUILD_SCRIPT ]]; then
    # Run ./build.sh script as 'www' user
    su www -c "./$NEOS_USER_BUILD_SCRIPT"
  fi
}




install_typo3_neos
cd $NEOS_ROOT

wait_for_db && create_app_db
create_settings_yaml

# Only proceed with doctrine:migration and creating admin user if it's fresh installation...
if [[ $(get_latest_db_migration) == 0 ]]; then
  log "Fresh installaction detected: making DB migration and creating admin user."
  doctrine_update
  create_admin_user
  install_site_package $NEOS_APP_SITE_PACKAGE
# Re-import the site, if requested
elif [ "${NEOS_APP_FORCE_SITE_REIMPORT^^}" = TRUE ]; then
  log "NEOS_APP_FORCE_SITE_REIMPORT=${NEOS_APP_FORCE_SITE_REIMPORT}, re-importing $NEOS_APP_SITE_PACKAGE site package."
  prune_site_package
  install_site_package $NEOS_APP_SITE_PACKAGE
# Nothing else to do...
else
  log "Neos db already provisioned, skipping..."
fi

warmup_cache "Production" # Warm-up caches for Production context
set_permissions

create_vhost_conf $NEOS_APP_VHOST_NAMES
user_build_script

log "Installation completed." && echo
