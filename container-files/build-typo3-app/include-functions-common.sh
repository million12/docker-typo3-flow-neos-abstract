#!/bin/bash

#######################################
# Echo/log function
# Arguments:
#   String: value to log
#######################################
log() {
  if [[ "$@" ]]; then echo "[${T3APP_NAME^^}] $@";
  else echo; fi
}

#########################################################
# Configure composer
#########################################################
function configure_composer() {
  # Increase timeout for composer complete install - it might take a while sometimes to install whole Flow/Neos
  composer config --global process-timeout 1800
  
  # This is an automated build, so if there are any changes in vendors packages, discard them w/o asking
  composer config --global discard-changes true
}


#########################################################
# Clone and compose Flow/Neos app
#
# Globals:
#   T3APP_BUILD_REPO_URL
#   T3APP_BUILD_BRANCH
#   T3APP_BUILD_COMPOSER_PARAMS
# Arguments:
#   String: target_path, where git clones the repository
#########################################################
function clone_and_compose() {
  local target_path=$1
  
  # Pull from Gerrit mirror instead of git.typo3.org (workaround of instabillity of git.typo3.org)
  git config --global url."http://git.typo3.org".insteadOf git://git.typo3.org

  # Clone TYPO3 app code from provided repository
  git clone $T3APP_BUILD_REPO_URL $target_path && cd $target_path

  # Do composer install
  git checkout $T3APP_BUILD_BRANCH
  git log -10 --pretty=format:"%h %an %cr: %s" --graph
  composer install $T3APP_BUILD_COMPOSER_PARAMS
  echo && echo # Just to add an empty line after `composer` verbose output
}


#########################################################
# If the installed TYPO3 app contains build hook script
# (@see $T3APP_USER_BUILD_SCRIPT), it will run it.
# This script can be used to do all necessary steps to make
# the site up&running, e.g. compile CSS, configure extra
# settings in YAML files etc.
#
# Globals:
#   T3APP_USER_BUILD_SCRIPT
# Arguments:
#   String: param (optional), e.g. '--post-install'
#   String: user to run script as (optional), e.g. 'www'
#########################################################
function hook_user_build_script() {
  local param=${1:-''}
  local user=${2:-''}

  if [[ -f $T3APP_USER_BUILD_SCRIPT  ]]; then
    chmod +x $T3APP_USER_BUILD_SCRIPT
  else
    return 0
  fi
  
  log && log "Running user hook script with param '$param':"
  if [[ -n "$param" && ! $(grep -- $param $T3APP_USER_BUILD_SCRIPT) ]]; then
    log "No param '$param' found in $T3APP_USER_BUILD_SCRIPT script content. Skipping..."
    return 0
  fi

  # Run ./build.sh script (as specific user, if provided)
  if [[ -n "$user" ]]; then
    su $user -c '$T3APP_USER_BUILD_SCRIPT $param'
  else
    source $T3APP_USER_BUILD_SCRIPT $param
  fi
}
