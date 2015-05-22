#!/bin/sh

#
# Pre-install TYPO3 app from $T3APP_BUILD_REPO_URL
# into archived package in /tmp directory.
#
# This archive will be then used when container starts for the 1st time.
# We do that to avoid installing TYPO3 app during the runtime, which 
# can be slow and potentially error-prone (i.e. composer conflicts/timeouts etc).
#
# It is posible to not use pre-installed app and compose the app on first container
# start with setting T3APP_PREINSTALL variable to false 
# (and not calling RUN . /build-typo3-app/pre-install-typo3-app.sh your image).

set -e
set -u

# Needs to be absolute as user can call this script from Dockerfile in multiple ways...
source /build-typo3-app/include-variables.sh
source /build-typo3-app/include-functions-common.sh

log
log "Installing TYPO3 app from $T3APP_BUILD_REPO_URL ($T3APP_BUILD_BRANCH) repository..."
log

PREINSTALL_WORKING_DIR="/tmp"
cd $PREINSTALL_WORKING_DIR

configure_composer
clone_and_compose

hook_user_build_script --preinstall # TODO: backward-compatibility only, do not use, to be removed soon
hook_user_build_script --post-build

cd $PREINSTALL_WORKING_DIR
tar -zcf $INSTALLED_PACKAGE_NAME.tgz $INSTALLED_PACKAGE_NAME # prepare compressed .tgz archive with installed source code
rm -rf $INSTALLED_PACKAGE_NAME # remove installed source code, to minimise Docker image size

log
log "TYPO3 app from $T3APP_BUILD_REPO_URL ($T3APP_BUILD_BRANCH) installed."
log $(du -sh $INSTALLED_PACKAGE_NAME.tgz)
log 
