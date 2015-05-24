#!/bin/sh

###############################################
# ENV variables used during image build phase
###############################################
T3APP_BUILD_REPO_URL=${T3APP_BUILD_REPO_URL:="git://git.typo3.org/Flow/Distributions/Base.git"}
T3APP_BUILD_BRANCH=${T3APP_BUILD_BRANCH:="master"}
T3APP_BUILD_COMPOSER_PARAMS=${T3APP_BUILD_COMPOSER_PARAMS:="--prefer-source --optimize-autoloader"}



###############################################
# ENV variables used during container runtime
###############################################

T3APP_DO_INIT=${T3APP_DO_INIT:=true}
T3APP_DO_INIT_TESTS=${T3APP_DO_INIT_TESTS:=false}
T3APP_NAME=${T3APP_NAME:="typo3-app"}
T3APP_USER_NAME=${T3APP_USER_NAME:="admin"}
T3APP_USER_PASS=${T3APP_USER_PASS:="password"}
T3APP_USER_FNAME=${T3APP_USER_FNAME:="Admin"}
T3APP_USER_LNAME=${T3APP_USER_LNAME:="User"}
T3APP_VHOST_NAMES=${T3APP_VHOST_NAMES:="${T3APP_NAME} dev.${T3APP_NAME} behat.dev.${T3APP_NAME}"}
T3APP_NEOS_SITE_PACKAGE=${T3APP_NEOS_SITE_PACKAGE:=false}
T3APP_NEOS_SITE_PACKAGE_FORCE_REIMPORT=${T3APP_NEOS_SITE_PACKAGE_FORCE_REIMPORT:=false}
T3APP_ALWAYS_DO_PULL=${T3APP_ALWAYS_DO_PULL:=false}
T3APP_FORCE_VHOST_CONF_UPDATE=${T3APP_FORCE_VHOST_CONF_UPDATE:=true}
T3APP_USE_SURF_DEPLOYMENT=${T3APP_USE_SURF_DEPLOYMENT:=false}
T3APP_SURF_SMOKE_TEST_DOMAIN=${T3APP_SURF_SMOKE_TEST_DOMAIN:="next.$(echo $T3APP_VHOST_NAMES | cut -f 1 -d ' ')"} # by default: next.<1st vhost name from $T3APP_VHOST_NAMES>

# Database ENV variables
# Note: all DB_* variables are created by Docker when linking this container with MariaDB container (e.g. tutum/mariadb, million12/mariadb) with --link=mariadb-container-id:db option. 
T3APP_DB_HOST=${T3APP_DB_HOST:=${DB_PORT_3306_TCP_ADDR:="db"}}      # 1st take T3APP_DB_HOST, then DB_PORT_3306_TCP_ADDR (linked db container), then fallback to 'db' host
T3APP_DB_PORT=${T3APP_DB_PORT:=${DB_PORT_3306_TCP_PORT:="3306"}}    # 1st take T3APP_DB_PORT, then DB_PORT_3306_TCP_PORT (linked db container), then fallback to the default '3306' port
T3APP_DB_USER=${T3APP_DB_USER:=${DB_ENV_MARIADB_USER:="admin"}}     # 1st take T3APP_DB_USER, then DB_ENV_MARIADB_USER (linked db container), then fallback to the default 'admin' user
T3APP_DB_PASS=${T3APP_DB_PASS:=${DB_ENV_MARIADB_PASS:="password"}}  # 1st take T3APP_DB_PASS, then DB_ENV_MARIADB_PASS (linked db container), then fallback to dummy pass
T3APP_DB_NAME=${T3APP_DB_NAME:=${T3APP_NAME//[^a-zA-Z0-9]/_}}       # DB name: Fallback to T3APP_NAME if not provided. Replace all non-allowed in DB identifiers with '_' char

# Script relative to $APP_ROOT directory - if found there and it's executable,
# will be called at the end of the setup process.
T3APP_USER_BUILD_SCRIPT=${T3APP_USER_BUILD_SCRIPT:="./build.sh"}



########################################################
# Internal variables - there is no need to change them
# We put here only these internal variables, which
# needs to be shared between pre-install-typo3-app.sh 
# and configure-typo3-app.sh scripts.
########################################################
PREINSTALL_WORKING_DIR="/tmp"
PREINSTALL_PACKAGE_NAME="typo3-app-package" # Pre-installed to /PREINSTALL_WORKING_DIR/PREINSTALL_PACKAGE_NAME.tgz
