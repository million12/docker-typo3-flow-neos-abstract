FROM test/typo3-flow-neos-abstract
MAINTAINER Marcin Ryzycki marcin@m12.io
 
ENV \
  T3APP_BUILD_REPO_URL=https://git.typo3.org/Flow/Distributions/Base.git \
  T3APP_BUILD_BRANCH=3.0

# Pre-install TYPO3 Flow into /tmp directory
RUN /build-typo3-app/pre-install-typo3-app.sh
