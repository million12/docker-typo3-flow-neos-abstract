#!/bin/sh

###############################################
# ENV variables used during image build phase
###############################################
T3APP_BUILD_REPO_URL=${T3APP_BUILD_REPO_URL:="git://git.typo3.org/Flow/Distributions/Base.git"}
T3APP_BUILD_BRANCH=${T3APP_BUILD_BRANCH:="master"}
T3APP_BUILD_COMPOSER_PARAMS=${T3APP_BUILD_COMPOSER_PARAMS:="--dev --prefer-source"}



###############################################
# ENV variables used during container runtime
###############################################
T3APP_DO_INIT=${T3APP_DO_INIT:=true}
T3APP_DO_INIT_TESTS=${T3APP_DO_INIT_TESTS:=false}
T3APP_NAME=${T3APP_NAME:="typo3-app"}
T3APP_DB_NAME=${T3APP_DB_NAME:=${T3APP_NAME//[^a-zA-Z0-9]/_}} # just in case replace with _ all non-allowed in DB name characters
T3APP_USER_NAME=${T3APP_USER_NAME:="admin"}
T3APP_USER_PASS=${T3APP_USER_PASS:="password"}
T3APP_USER_FNAME=${T3APP_USER_FNAME:="Admin"}
T3APP_USER_LNAME=${T3APP_USER_LNAME:="User"}
T3APP_VHOST_NAMES=${T3APP_VHOST_NAMES:="${T3APP_NAME} dev.${T3APP_NAME} behat.dev.${T3APP_NAME}"}
T3APP_NEOS_SITE_PACKAGE=${T3APP_NEOS_SITE_PACKAGE:=false}
T3APP_NEOS_SITE_PACKAGE_FORCE_REIMPORT=${T3APP_NEOS_SITE_PACKAGE_FORCE_REIMPORT:=false}
T3APP_ALWAYS_DO_PULL=${T3APP_ALWAYS_DO_PULL:=false}
T3APP_FORCE_VHOST_CONF_UPDATE=${T3APP_FORCE_VHOST_CONF_UPDATE:=true}

# Script relative to $APP_ROOT directory - if found there and it's executable,
# will be called at the end of the setup process.
T3APP_USER_BUILD_SCRIPT=${T3APP_USER_BUILD_SCRIPT:="./build.sh"}



########################################################
# Internal variables - there is no need to change them
# We put here only these internal variables, which
# needs to be shared between pre-install-typo3-app.sh 
# and configure-typo3-app.sh scripts.
########################################################
INSTALLED_PACKAGE_NAME="typo3-app-package" # Pre-installed /tmp/INSTALLED_PACKAGE_NAME.tgz
