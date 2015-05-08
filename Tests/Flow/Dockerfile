FROM million12/typo3-flow-neos-abstract:latest
MAINTAINER Marcin Ryzycki marcin@m12.io

# ENV: Repository for installed TYPO3 Flow distribution 
ENV T3APP_BUILD_REPO_URL git://git.typo3.org/Flow/Distributions/Base.git

# ENV: Install the following Flow version
ENV T3APP_BUILD_BRANCH master

# Pre-install TYPO3 Flow into /tmp directory
RUN . /build-typo3-app/pre-install-typo3-app.sh
