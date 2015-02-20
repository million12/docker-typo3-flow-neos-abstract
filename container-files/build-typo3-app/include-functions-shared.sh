#!/bin/sh

#########################################################
# Clone and compose app.
# Expected to be executed within /tmp.
# Globals:
#   INSTALLED_PACKAGE_NAME
#   T3APP_BUILD_BRANCH
#   T3APP_BUILD_REPO_URL
#   T3APP_BUILD_COMPOSER_PARAMS
#   T3APP_USER_BUILD_SCRIPT
#########################################################
function clone_and_compose() {
  # Internal variables
  CWD="/tmp"
  # Internal variables end

  cd $CWD

  # Pull from Gerrit mirror instead of git.typo3.org (workaround of instabillity of git.typo3.org)
  git config --global url."http://git.typo3.org".insteadOf git://git.typo3.org

  # Clone TYPO3 app code from provided repository
  git clone $T3APP_BUILD_REPO_URL $INSTALLED_PACKAGE_NAME
  cd $INSTALLED_PACKAGE_NAME

  # Do composer install
  git checkout $T3APP_BUILD_BRANCH
  git log -10 --pretty=format:"%h %an %cr: %s" --graph
  COMPOSER_PROCESS_TIMEOUT=900 composer install $T3APP_BUILD_COMPOSER_PARAMS

  # If the project contains executable build.sh in the root directory
  # it will be run during 'docker build' process. Note: it's OK to run is as root 
  # as it might need these privileges to install some global tools.
  if [[ -x $T3APP_USER_BUILD_SCRIPT ]]; then $T3APP_USER_BUILD_SCRIPT --preinstall; fi
}
