#!/bin/sh

#
# Initialise/configure TYPO3 Neos pre-installed during 'docker build'
# and located in /tmp/INSTALLED_PACKAGE_NAME.tgz (@see install_typo3_neos() below)
#

set -e
set -u

#
# ENV variables passed to container. If they are not provided, default values are used.
#
NEOS_APP_DO_INIT=${NEOS_APP_DO_INIT:=true}
NEOS_APP_DO_INIT_TESTS=${NEOS_APP_DO_INIT_TESTS:=false}
NEOS_APP_NAME=${NEOS_APP_NAME:="neos"}
NEOS_APP_DB_NAME=${NEOS_APP_DB_NAME:="typo3_neos"}
NEOS_APP_USER_NAME=${NEOS_APP_USER_NAME:="admin"}
NEOS_APP_USER_PASS=${NEOS_APP_USER_PASS:="password"}
NEOS_APP_USER_FNAME=${NEOS_APP_USER_FNAME:="Admin"}
NEOS_APP_USER_LNAME=${NEOS_APP_USER_LNAME:="User"}
NEOS_APP_VHOST_NAMES=${NEOS_APP_VHOST_NAMES:="${NEOS_APP_NAME} dev.${NEOS_APP_NAME} behat.dev.${NEOS_APP_NAME}"}
NEOS_APP_SITE_PACKAGE=${NEOS_APP_SITE_PACKAGE:=false}
NEOS_APP_FORCE_PULL=${NEOS_APP_FORCE_PULL:=false}
NEOS_APP_FORCE_SITE_REIMPORT=${NEOS_APP_FORCE_SITE_REIMPORT:=false}
NEOS_APP_FORCE_VHOST_CONF_UPDATE=${NEOS_APP_FORCE_VHOST_CONF_UPDATE:=true}
TYPO3_NEOS_COMPOSER_PARAMS=${TYPO3_NEOS_COMPOSER_PARAMS:="--optimize-autoloader"}
#
# ENV variables (end)
#


# Internal variables - there is no need to change them
CWD=$(pwd) # Points to /build-typo3-app/ directory, where this script is located
INSTALLED_PACKAGE_NAME="typo3-app-package" # Pre-installed /tmp/INSTALLED_PACKAGE_NAME.tgz
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
    cd $WEB_ROOT && tar -zxf /tmp/$INSTALLED_PACKAGE_NAME.tgz
    mv $INSTALLED_PACKAGE_NAME $NEOS_APP_NAME
  fi

  log "Neos installed."
  cd $NEOS_ROOT
  
  # Make sure cache is cleared for all contexts. This is empty during the 1st container launch,
  # but not clearing it when container re-starts can cause random issues.
  rm -rf rm -rf Data/Temporary/*
  
  # Debug: show most recent git log messages
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
#   MYSQL_CMD_AUTH_PARAMS
# Arguments:
#   String: db name to create
#########################################################
function create_app_db() {
  local db_name=$@
  log "Creating Neos db '$db_name' (if it doesn't exist yet)..."
  mysql $MYSQL_CMD_AUTH_PARAMS --execute="CREATE DATABASE IF NOT EXISTS $db_name CHARACTER SET utf8 COLLATE utf8_general_ci"
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

  # Create fresh vhost file on new data volume
  if [ ! -f $VHOST_FILE ]; then
    cat $VHOST_SOURCE_FILE > $VHOST_FILE
    log "New vhost file created."
  # Vhost already exist, but NEOS_APP_FORCE_VHOST_CONF_UPDATE=true, so override it.
  elif [ "${NEOS_APP_FORCE_VHOST_CONF_UPDATE^^}" = TRUE ]; then
    cat $VHOST_SOURCE_FILE > $VHOST_FILE
    log "Vhost file updated (as NEOS_APP_FORCE_VHOST_CONF_UPDATE is TRUE)."
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
#   DB_ENV_MARIADB_PASS
#   DB_PORT_3306_TCP_ADDR
#   DB_PORT_3306_TCP_PORT
# Arguments:
#   String: filepath to config file to create/configure
#   String: database name to put in Settings.yaml
#########################################################
function create_settings_yaml() {
  local settings_file=$1
  local settings_db_name=$2

  mkdir -p $(dirname $settings_file)
  
  if [ ! -f $settings_file ]; then
    cat $SETTINGS_SOURCE_FILE > $settings_file
    log "Configuration file $settings_file created."
  fi

  log "Configuring $settings_file..."
  sed -i -r "1,/dbname:/s/dbname: .+?/dbname: $settings_db_name/g" $settings_file
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
  if [ "${site_package_name^^}" = FALSE ]; then
    log "Skipping installing site package (NEOS_APP_SITE_PACKAGE is set to FALSE)."
  else
    log "Installing $site_package_name site package..."
    ./flow site:import --packageKey $site_package_name
  fi
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
wait_for_db

#
# Regular TYPO3 Neos app initialisation
# 
if [ "${NEOS_APP_DO_INIT^^}" = TRUE ]; then
  log "Configuring TYPO3 Neos app..." && log
  
  create_app_db $NEOS_APP_DB_NAME
  create_settings_yaml "Configuration/Settings.yaml" $NEOS_APP_DB_NAME
  
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
fi
# Regular TYPO3 Neos app (END)


#
# Initialise TYPO3 Neos for running test
# 
if [ "${NEOS_APP_DO_INIT_TESTS^^}" = TRUE ]; then
  log "Configuring TYPO3 Neos app for testing..." && log

  testing_db_name="${NEOS_APP_DB_NAME}_test"
  
  create_app_db $testing_db_name
  create_settings_yaml "Configuration/Development/Behat/Settings.yaml" $testing_db_name
  create_settings_yaml "Configuration/Testing/Behat/Settings.yaml" $testing_db_name
  
  # Find vhost name for Behat. That should be 'behat.dev.[BASE_DOMAIN_NAME]' in NEOS_APP_VHOST_NAMES variable.
  behat_vhost=""
  for vhost in $NEOS_APP_VHOST_NAMES; do
    if [[ $vhost == *behat* ]]; then
      behat_vhost=$vhost
    fi
  done
  
  # Exit if Behat host could not be determined.
  if [ -z $behat_vhost ]; then
    log "ERROR: Could not find vhost name for Behat!"
    log "Please provide *behat.dev.[BASE_DOMAIN]* to NEOS_APP_VHOST_NAMES environment variable."
    exit 1
  else
    log "Vhost used for Behat testing found: $behat_vhost"
  fi

  # Iterate through all packages */Tests/Behavior/behat.yml files and set there behat vhost
  for f in Packages/*/*/Tests/Behavior/behat.yml.dist; do
    target_file=${f/.dist/}
    if [ ! -f $target_file ]; then
      cp $f $target_file
    fi
    # Find all base_url: setting (might be commented out) and replace it with $behat_vhost
    sed -i -r "s/(#\s?)?base_url:.+/base_url: http:\/\/${behat_vhost}\//g" $target_file
    log "$target_file configured for Behat testing."
  done
  
  warmup_cache "Development/Behat" # Warm-up caches for Behat tests
  
  ./flow behat:setup
fi
# Initialise TYPO3 Neos for running test (END)

set_permissions
create_vhost_conf $NEOS_APP_VHOST_NAMES
user_build_script

log "Installation completed." && echo
