#!/bin/sh

#########################################################
# Check in the loop (every 2s) if the database backend
# service is already available.
# Globals:
#   T3APP_DB_HOST: db hostname
#   T3APP_DB_PORT: db port number
#   T3APP_DB_USER: db username
#   MYSQL_CMD_PARAMS
#########################################################
function wait_for_db() {
  set +e
  local res=1
  while [[ $res -ne 0 ]]; do
    mysql $MYSQL_CMD_PARAMS --execute "status" 1>/dev/null
    res=$?
    if [[ $res -ne 0 ]]; then log "Waiting for DB service ($T3APP_DB_HOST:$T3APP_DB_PORT username:$T3APP_DB_USER)..." && sleep 2; fi
  done
  set -e
  
  # Display DB status...
  log "Database status:"
  mysql $MYSQL_CMD_PARAMS --execute "status"
}

#########################################################
# Moves pre-installed in /tmp TYPO3 to its
# target location ($APP_ROOT), if it's not there yet
# Globals:
#   WEB_SERVER_ROOT
#   APP_ROOT
#   T3APP_NAME
#   T3APP_BUILD_BRANCH
#########################################################
function install_typo3_app() {
  # Check if app is already installed (when restaring stopped container)
  if [ ! -d $APP_ROOT ]; then
    if [ "${T3APP_PREINSTALL^^}" = TRUE ]; then
      log "Installing TYPO3 app (from pre-installed archive)..."
      cd $WEB_SERVER_ROOT && tar -zxf /tmp/$INSTALLED_PACKAGE_NAME.tgz
      mv $INSTALLED_PACKAGE_NAME $T3APP_NAME
    else
      log "Installing TYPO3 app..."
      cd $WEB_SERVER_ROOT
      # Clone TYPO3 app code from provided repository
      git clone $T3APP_BUILD_REPO_URL $T3APP_NAME
      cd $T3APP_NAME
      # Do composer install
      git checkout $T3APP_BUILD_BRANCH
      git log -10 --pretty=format:"%h %an %cr: %s" --graph
      composer install $T3APP_BUILD_COMPOSER_PARAMS
      echo
      echo "TYPO3 app from $T3APP_BUILD_REPO_URL ($T3APP_BUILD_BRANCH) installed."
      echo $(ls -lh $CWD)
      echo
    fi
  fi

  cd $APP_ROOT
  
  # Make sure cache is cleared for all contexts. This is empty during the 1st container launch,
  # but, when container is re-run (with shared data volume), not clearing it can cause random issues
  # (e.g. due to changes in the newly pulled code).
  rm -rf Data/Temporary/*
  
  # Debug: show most recent git log messages
  log "TYPO3 app installed. Most recent commits:"
  git log -5 --pretty=format:"%h %an %cr: %s" --graph && echo # Show most recent changes
  
  # If app is/was already installed, pull the most recent code
  if [ "${T3APP_ALWAYS_DO_PULL^^}" = TRUE ]; then
    install_typo3_app_do_pull
  fi
  
  # If composer.lock has changed, this will re-install things...
  composer install $T3APP_BUILD_COMPOSER_PARAMS
}

#########################################################
# Pull the newest codebase from the remote repository.
# It tries to handle the situation even when they are
# conflicting changes.
#
# Called when T3APP_ALWAYS_DO_PULL is set to TRUE.
#
# Globals:
#   WEB_SERVER_ROOT
#   APP_ROOT
#   T3APP_NAME
#########################################################
function install_typo3_app_do_pull() {
  set +e # allow non-zero command results (git pull might fail due to code conflicts)
  log "Pulling the newest codebase (due to T3APP_ALWAYS_DO_PULL set to TRUE)..."

  if [[ ! $(git status | grep "working directory clean") ]]; then
    log "There are some changes in the current working directory. Stashing..."
    git status
    git stash --include-untracked
  fi
  
  # Allow switching between branches for running containers
  # E.g. user can provide different branch for `docker build` (in Dockerfile)
  # and different when launching the container.
  git fetch && git checkout --force $T3APP_BUILD_BRANCH
  
  if [[ ! $(git pull -f) ]]; then
    log "git pull failed. Trying once again with 'git reset --hard origin/${T3APP_BUILD_BRANCH}'..."
    git reset --hard origin/$T3APP_BUILD_BRANCH
  fi
  
  log "Most recent commits (after newest codebase has been pulled):"
  git log -10 --pretty=format:"%h %an %cr: %s" --graph
  
  set -e # restore -e setting
}


#########################################################
# Creates database for TYPO3 app, if doesn't exist yet
# Globals:
#   MYSQL_CMD_PARAMS
# Arguments:
#   String: db name to create
#########################################################
function create_app_db() {
  local db_name=$@
  log "Creating TYPO3 app database '$db_name' (if it doesn't exist yet)..."
  mysql $MYSQL_CMD_PARAMS --execute="CREATE DATABASE IF NOT EXISTS $db_name CHARACTER SET utf8 COLLATE utf8_unicode_ci"
  log "DB created."
}

#########################################################
# Create Nginx vhost, if it doesn't exist yet
# Globals:
#   APP_ROOT
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
  # Vhost already exist, but T3APP_FORCE_VHOST_CONF_UPDATE=true, so override it.
  elif [ "${T3APP_FORCE_VHOST_CONF_UPDATE^^}" = TRUE ]; then
    cat $VHOST_SOURCE_FILE > $VHOST_FILE
    log "Vhost file updated (as T3APP_FORCE_VHOST_CONF_UPDATE is TRUE)."
  fi

  sed -i -r "s#%server_name%#${vhost_names}#g" $VHOST_FILE
  sed -i -r "s#%root%#${APP_ROOT}#g" $VHOST_FILE
  
  # Configure redirect: www to non-www
  # @TODO: make it configurable via env var
  # @TODO: make possible reversed behaviour (non-www to www)
  sed -i -r "s#%server_name_primary%#${vhost_names_arr[0]}#g" $VHOST_FILE
  
  cat $VHOST_FILE
  log "Nginx vhost configured."
}

#########################################################
# Update TYPO3 app Settings.yaml with DB backend settings
# Globals:
#   SETTINGS_SOURCE_FILE
#   T3APP_DB_HOST
#   T3APP_DB_PORT
#   T3APP_DB_USER
#   T3APP_DB_PASS
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
  sed -i -r "1,/user:/s/user: .+?/user: $T3APP_DB_USER/g" $settings_file
  sed -i -r "1,/password:/s/password: .+?/password: $T3APP_DB_PASS/g" $settings_file
  sed -i -r "1,/host:/s/host: .+?/host: $T3APP_DB_HOST/g" $settings_file
  sed -i -r "1,/port:/s/port: .+?/port: $T3APP_DB_PORT/g" $settings_file

  cat $settings_file
  log "$settings_file updated."
}

#########################################################
# Check latest TYPO3 doctrine:migration status.
# Used to detect if this is fresh installation
# or re-run from previous state.
#########################################################
function get_db_executed_migrations() {
  local v=$(./flow doctrine:migrationstatus | grep -i 'Executed Migrations' | awk '{print $4$5}')
  echo $v
}

#########################################################
# Provision database (i.e. doctrine:migrate)
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
  ./flow user:create --roles Administrator $T3APP_USER_NAME $T3APP_USER_PASS $T3APP_USER_FNAME $T3APP_USER_LNAME
}

#########################################################
# Install site package
# Arguments:
#   String: site package name to install
#########################################################
function neos_site_package_install() {
  local site_package_name=$@
  if [ "${site_package_name^^}" = FALSE ]; then
    log "Skipping installing site package (T3APP_NEOS_SITE_PACKAGE is set to FALSE)."
  else
    log "Installing $site_package_name site package..."
    ./flow site:import --packageKey $site_package_name
  fi
}

#########################################################
# Prune all site data.
# Used when re-importing the site package.
#########################################################
function neos_site_package_prune() {
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
# Set correct permission for TYPO3 app
#########################################################
function set_permissions() {
  chown -R www:www $APP_ROOT
}

#########################################################
# Get virtual host name used for Behat testing.
# This host name has in format 'behat.dev.[BASE_DOMAIN]' 
# We relay on the fact that Nginx is configured that
# it sets FLOW_CONTEXT to Development when 'dev' string
# is detected in hostname and respectively
# Development/Behat if 'behat' string is detected.
# Globals:
#   T3APP_VHOST_NAMES: all vhost name(s), space-separated  
#########################################################
function behat_get_vhost() {
  behat_vhost=""
  for vhost in $T3APP_VHOST_NAMES; do
    if [[ $vhost == *behat* ]]; then
      behat_vhost=$vhost
    fi
  done
  
  echo $behat_vhost
}

#########################################################
# Iterate through all installed packages in Packages/
# look up for */Tests/Behavior/behat.yml[.dist] files 
# and set there behat vhost in base_url: variable.
# Arguments:
#   String: vhost used for Behat tests
#########################################################
function behat_configure_yml_files() {
  local behat_vhost=$@

  cd $APP_ROOT;
  for f in Packages/*/*/Tests/Behavior/behat.yml.dist; do
    target_file=${f/.dist/}
    if [ ! -f $target_file ]; then
      cp $f $target_file
    fi
    # Find all base_url: setting (might be commented out) and replace it with $behat_vhost
    sed -i -r "s/(#\s?)?base_url:.+/base_url: http:\/\/${behat_vhost}\//g" $target_file
    log "$target_file configured for Behat testing."
  done
}


#########################################################
# Configure environment (e.g. PATH).
# Configure .bash_profile for 'www' user with all 
# necessary scripts/settings like /etc/hosts settings.
# Globals:
#   APP_ROOT
#   BASH_RC_FILE
#   BASH_RC_SOURCE_FILE
#   CONTAINER_IP
#   T3APP_BUILD_BRANCH
#   T3APP_VHOST_NAMES
#   T3APP_NAME
#   T3APP_USER_NAME
#########################################################
function configure_env() {
  configure_composer

  # Configure git
  # To make sure git stash/pull always works. Otherwise git shouts about missing configuration.
  # Note: the actual values doesn't matter, most important is that they are configured.
  git config --global user.email "${T3APP_USER_NAME}@local"
  git config --global user.name $T3APP_USER_NAME

  # Add T3APP_VHOST_NAMES to /etc/hosts inside this container
  echo "127.0.0.1 $T3APP_VHOST_NAMES" | tee -a /etc/hosts

  # Copy .bash_profile and substitute all necessary variables
  cat $BASH_RC_SOURCE_FILE > $BASH_RC_FILE && chown www:www $BASH_RC_FILE
  sed -i -r "s#%CONTAINER_IP%#${CONTAINER_IP}#g" $BASH_RC_FILE
  sed -i -r "s#%APP_ROOT%#${APP_ROOT}#g" $BASH_RC_FILE
  sed -i -r "s#%T3APP_BUILD_BRANCH%#${T3APP_BUILD_BRANCH}#g" $BASH_RC_FILE
  sed -i -r "s#%T3APP_NAME%#${T3APP_NAME}#g" $BASH_RC_FILE
  sed -i -r "s#%T3APP_VHOST_NAMES%#${T3APP_VHOST_NAMES}#g" $BASH_RC_FILE
}
