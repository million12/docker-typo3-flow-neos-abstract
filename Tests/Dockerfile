#
# This file is just for development purposes.
# Might be useful during development of this image.
# It leverages Docker caching to speed up image building
# while you develop e.g. configure-typo3-app.sh script.
#
FROM million12/nginx-php:latest

ADD container-files/config /
ADD container-files/etc /
ADD container-files/build-typo3-app/include-variables.sh /build-typo3-app/include-variables.sh
ADD container-files/build-typo3-app/include-functions-common.sh /build-typo3-app/include-functions-common.sh
ADD container-files/build-typo3-app/pre-install-typo3-app.sh /build-typo3-app/pre-install-typo3-app.sh

ENV \
  T3APP_BUILD_REPO_URL=https://github.com/neos/neos-base-distribution.git \
  T3APP_BUILD_BRANCH=2.0 \
  T3APP_NEOS_SITE_PACKAGE=TYPO3.NeosDemoTypo3Org

RUN . /build-typo3-app/pre-install-typo3-app.sh

ADD container-files /
