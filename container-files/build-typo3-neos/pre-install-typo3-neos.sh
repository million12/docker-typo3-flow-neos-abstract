#!/bin/sh

#
# Pre-install TYPO3 Neos from $TYPO3_NEOS_REPO_URL
# into archived package in /tmp/typo3-neos.tgz.
#
# This archive will be then used when container starts for the 1st time.
# We do that to avoid installing Neos during runtime, which is slow
# and potentially error-prone (i.e. composer conflicts/timeouts etc).
#

set -e
set -u

#
# ENV variables: override them if needed
#
TYPO3_NEOS_REPO_URL=${TYPO3_NEOS_REPO_URL:="git://git.typo3.org/Neos/Distributions/Base.git"}
TYPO3_NEOS_VERSION=${TYPO3_NEOS_VERSION:="master"}
TYPO3_NEOS_COMPOSER_PARAMS=${TYPO3_NEOS_COMPOSER_PARAMS:="--dev --prefer-source"}
#
# ENV variables (end)
#

echo
echo "Installing TYPO3 Neos *$TYPO3_NEOS_VERSION* from $TYPO3_NEOS_REPO_URL repository."
echo

# Internal variables
CWD="/tmp"
INSTALLED_PACKAGE_NAME="typo3-neos-package"

cd $CWD

# Clone Neos distribution from provided repository
git clone $TYPO3_NEOS_REPO_URL $INSTALLED_PACKAGE_NAME
cd $INSTALLED_PACKAGE_NAME
git log -10 --pretty=format:"%h %an %cr: %s" --graph

# Do composer install
git checkout $TYPO3_NEOS_VERSION
COMPOSER_PROCESS_TIMEOUT=900 composer install $TYPO3_NEOS_COMPOSER_PARAMS

# If the project contains executable build.sh in the root directory
# it will be run during 'docker build' process. Note: it's OK to run is as root 
# as it might need these privileges to install some global tools.
if [[ -x "build.sh" ]]; then ./build.sh --preinstall; fi

# Prepare tar archive and keep only it (remove neos dir)
cd $CWD
tar -zcf $INSTALLED_PACKAGE_NAME.tgz $INSTALLED_PACKAGE_NAME && rm -rf $INSTALLED_PACKAGE_NAME

echo
echo "TYPO3 Neos $TYPO3_NEOS_VERSION installed."
echo $(ls -lh $CWD)
echo 
