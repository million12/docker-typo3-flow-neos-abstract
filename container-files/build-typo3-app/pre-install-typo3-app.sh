#!/bin/sh

#
# Pre-install TYPO3 app from $T3APP_BUILD_REPO_URL
# into archived package in /tmp directory.
#
# This archive will be then used when container starts for the 1st time.
# We do that to avoid installing TYPO3 app during the runtime, which 
# can be slow and potentially error-prone (i.e. composer conflicts/timeouts etc).
#

set -e
set -u

# Needs to be absolute as user can call this script from Dockerfile in multiple ways...
source /build-typo3-app/include-variables.sh

echo
echo "Installing TYPO3 app from $T3APP_BUILD_REPO_URL ($T3APP_BUILD_BRANCH) repository..."
echo

# Internal variables
CWD="/tmp"
# Internal variables end

cd $CWD

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

# Prepare tar archive and keep only it to keep final Docker image size as small as possible
cd $CWD
tar -zcf $INSTALLED_PACKAGE_NAME.tgz $INSTALLED_PACKAGE_NAME && rm -rf $INSTALLED_PACKAGE_NAME

echo
echo "TYPO3 app from $T3APP_BUILD_REPO_URL ($T3APP_BUILD_BRANCH) installed."
echo $(ls -lh $CWD)
echo 
