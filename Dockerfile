FROM million12/php-app:latest
MAINTAINER Marcin Ryzycki marcin@m12.io

# Add all files from container-files/ to the root of the container's filesystem
ADD container-files /

#
# This is "abstract" image and it doesn't do anything on its own.
# It is designed to easily build sub-images which will run any TYPO3 Neos version.
# See README.md for more information.
#
