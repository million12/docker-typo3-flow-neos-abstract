#!/bin/sh

#
# Initialise/configure TYPO3 Neos pre-installed during 'docker build'
# and located in /tmp/INSTALLED_PACKAGE_NAME.tgz (@see install_typo3_neos() below)
#

set -e
set -u

source ./include-functions.sh
source ./include-variables.sh

# Internal variables - there is no need to change them
CWD=$(pwd) # Points to /build-typo3-app/ directory, where this script is located
INSTALLED_PACKAGE_NAME="typo3-app-package" # Pre-installed /tmp/INSTALLED_PACKAGE_NAME.tgz
WEB_SERVER_ROOT="/data/www"
NEOS_ROOT="${WEB_SERVER_ROOT}/${NEOS_APP_NAME}"
SETTINGS_SOURCE_FILE="${CWD}/Settings.yaml"
VHOST_SOURCE_FILE="${CWD}/vhost.conf"
VHOST_FILE="/data/conf/nginx/hosts.d/${NEOS_APP_NAME}.conf"
DB_ENV_MARIADB_PASS=${DB_ENV_MARIADB_PASS:="password"}
DB_PORT_3306_TCP_ADDR=${DB_PORT_3306_TCP_ADDR:="127.0.0.1"}
DB_PORT_3306_TCP_PORT=${DB_PORT_3306_TCP_PORT:="3306"}
MYSQL_CMD_AUTH_PARAMS="--user=admin --password=$DB_ENV_MARIADB_PASS --host=$DB_PORT_3306_TCP_ADDR --port=$DB_PORT_3306_TCP_PORT"

#
# TYPO3 app installation
#
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
