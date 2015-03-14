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
source /build-typo3-app/include-functions-shared.sh

echo
echo "Installing TYPO3 app from $T3APP_BUILD_REPO_URL ($T3APP_BUILD_BRANCH) repository..."
echo

# Internal variables
CWD="/tmp"
# Internal variables end

clone_and_compose

# Prepare tar archive and keep only it to keep final Docker image size as small as possible
cd $CWD
tar -zcf $INSTALLED_PACKAGE_NAME.tgz $INSTALLED_PACKAGE_NAME && rm -rf $INSTALLED_PACKAGE_NAME

echo
echo "TYPO3 app from $T3APP_BUILD_REPO_URL ($T3APP_BUILD_BRANCH) installed."
echo $(ls -lh $CWD)
echo 
