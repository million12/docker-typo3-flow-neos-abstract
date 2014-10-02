FROM million12/php-app:latest
MAINTAINER Marcin Ryzycki marcin@m12.io

# Add all files from container-files/ to the root of the container's filesystem
ADD container-files /

#
# This is "abstract" image and it doesn't do anything on its own.
# It is designed to easily build sub-images which will run any TYPO3 Neos version.
# See README.md for more information.
#
# If you need to access your private repository, you'll need to add ssh keys to the image
# and configure SSH to use them. You can do this in following way:
# ADD gh-repo-key /
# RUN \
#   chmod 600 /gh-repo-key && \
#   echo "IdentityFile /gh-repo-key" >> /etc/ssh/ssh_config

# In your image based on this one you will have to run this script:
#RUN . /build-typo3-neos/pre-install-typo3-neos.sh
