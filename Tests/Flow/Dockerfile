FROM million12/typo3-flow-neos-abstract:latest
MAINTAINER Marcin Ryzycki marcin@m12.io

# ENV: Repository for installed TYPO3 Neos distribution 
ENV T3APP_BUILD_REPO_URL git://git.typo3.org/Flow/Distributions/Base.git

# ENV: Install following TYPO3 Neos version
ENV T3APP_BUILD_BRANCH 2.2.2

# Pre-install TYPO3 Flow into /tmp directory
RUN . /build-typo3-app/pre-install-typo3-app.sh
