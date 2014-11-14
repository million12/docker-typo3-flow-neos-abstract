#!/bin/sh

#
# Initialise/configure TYPO3 app pre-installed during 'docker build'
# and located in /tmp/INSTALLED_PACKAGE_NAME.tgz (@see install_typo3_app() function)
#

set -e
set -u

source ./include-functions.sh
source ./include-variables.sh

# Internal variables - there is no need to change them
CWD=$(pwd) # Points to /build-typo3-app/ directory, where this script is located
WEB_SERVER_ROOT="/data/www"
APP_ROOT="${WEB_SERVER_ROOT}/${T3APP_NAME}"
INSTALLATION_TYPE="flow" # Default installation type, will be set later on if different one (e.g. Neos) is detected
SETTINGS_SOURCE_FILE="${CWD}/Settings.yaml"
VHOST_SOURCE_FILE="${CWD}/vhost.conf"
VHOST_FILE="/data/conf/nginx/hosts.d/${T3APP_NAME}.conf"
DB_ENV_MARIADB_PASS=${DB_ENV_MARIADB_PASS:="password"}
DB_PORT_3306_TCP_ADDR=${DB_PORT_3306_TCP_ADDR:="127.0.0.1"}
DB_PORT_3306_TCP_PORT=${DB_PORT_3306_TCP_PORT:="3306"}
MYSQL_CMD_AUTH_PARAMS="--user=admin --password=$DB_ENV_MARIADB_PASS --host=$DB_PORT_3306_TCP_ADDR --port=$DB_PORT_3306_TCP_PORT"

#
# TYPO3 app installation
#
install_typo3_app
cd $APP_ROOT
wait_for_db


# Detect real INSTALLATION_TYPE, based on what's found in composer.json
grep "typo3/neos" composer.json && INSTALLATION_TYPE="neos"
log && log "Detected installation type: ${INSTALLATION_TYPE^^}."


#
# Regular TYPO3 app initialisation
# 
if [ "${T3APP_DO_INIT^^}" = TRUE ]; then
  log "Configuring TYPO3 app..." && log
  
  create_app_db $T3APP_DB_NAME
  create_settings_yaml "Configuration/Settings.yaml" $T3APP_DB_NAME
  
  # Only proceed with doctrine:migration it is a fresh installation...
  executed_migrations=$(get_db_executed_migrations)
  log "DB executed migrations: $executed_migrations"
  
  if [[ $executed_migrations == 0 ]]; then
    log "Fresh installation detected: making DB migration:"
    doctrine_update
  else
    log "TYPO3 app database already provisioned, skipping..."
  fi

  # TYPO3 Neos steps only:
  if [[ $INSTALLATION_TYPE == "neos" ]]; then
    log "Continuing with TYPO3 Neos steps installation:"
    if [[ $executed_migrations == 0 ]]; then
      log "Fresh installation detected: creating admin user, importing site package:"
      create_admin_user
      neos_site_package_install $T3APP_NEOS_SITE_PACKAGE
    # Re-import the site, if requested
    elif [ "${T3APP_NEOS_SITE_PACKAGE_FORCE_REIMPORT^^}" = TRUE ]; then
      log "T3APP_NEOS_SITE_PACKAGE_FORCE_REIMPORT=${T3APP_NEOS_SITE_PACKAGE_FORCE_REIMPORT}, re-importing $T3APP_NEOS_SITE_PACKAGE site package."
      neos_site_package_prune
      neos_site_package_install $T3APP_NEOS_SITE_PACKAGE
    else
      log "TYPO3 Neos already set up, nothing to do."
    fi
  fi
  
  warmup_cache "Production" # Warm-up caches for Production context
fi
# Regular TYPO3 app initialisation (END)


#
# Initialise TYPO3 app for running test
# 
if [ "${T3APP_DO_INIT_TESTS^^}" = TRUE ]; then
  log "Configuring TYPO3 app for testing..." && log
  
  # @TODO: is there anything to do here when Behat is not available? Not sure...
  # Seems like functional tests can run without any extra configuration in Testing context.

  # Only proceed with Behat setup if it is available...
  if [[ $(./flow help | grep "behat:setup") ]]; then
    testing_db_name="${T3APP_DB_NAME}_test"
    create_app_db $testing_db_name
    
    # Find vhost name for Behat. That should be 'behat.dev.[BASE_DOMAIN_NAME]' in T3APP_VHOST_NAMES variable.
    # Exit if Behat host could not be determined.
    behat_vhost=$(behat_get_vhost)
    if [ -z $behat_vhost ]; then
      log "ERROR: Could not find vhost name for Behat!"
      log "Please provide *behat.dev.[BASE_DOMAIN]* to T3APP_VHOST_NAMES environment variable."
      exit 1
    else
      log "Detected virtual host used for Behat testing: $behat_vhost"
    fi

    # Configure FLOW_CONTEXTs for Behat
    create_settings_yaml "Configuration/Testing/Behat/Settings.yaml" $testing_db_name
    create_settings_yaml "Configuration/Development/Behat/Settings.yaml" $testing_db_name
    
    # Configure behat.yml files
    behat_configure_yml_files $behat_vhost
    # Install Behat dependencies
    ./flow behat:setup
    # Warm-up caches
    warmup_cache "Development/Behat"
  fi
fi
# Initialise TYPO3 app for running test (END)



set_permissions
create_vhost_conf $T3APP_VHOST_NAMES
user_build_script

log "Installation completed." && echo
