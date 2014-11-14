# TYPO3 Flow/Neos | Abstract Docker image
[![Circle CI](https://circleci.com/gh/million12/docker-typo3-neos-abstract.png?style=badge)](https://circleci.com/gh/million12/docker-typo3-neos-abstract)

This is a Docker image [million12/typo3-flow-neos-abstract](https://registry.hub.docker.com/u/million12/typo3-flow-neos-abstract) which is **designed to easily create images with standard or customised installation** of [TYPO3 Flow](http://flow.typo3.org/) or [TYPO3 Neos](http://neos.typo3.org/). Your image can be build from  either the default "base" distribution or your own, perhaps private, repository. 

For an **example of TYPO3 Flow image** built on top of this one, see [million12/typo3-flow](https://github.com/million12/docker-typo3-flow) repository.

For an **example of TYPO3 Neos image** built on top of this one, see [million12/typo3-neos](https://github.com/million12/docker-typo3-neos) repository.

The image is designed that after running a container from it, you'll get working TYPO3 Flow/Neos in a matter of seconds. When the image is being build, it pre-installs (via `composer install`) requested version of TYPO3 Flow/Neos into /tmp location. Later on, when the container is run, it will initialise and configure that pre-installed package. This process is very quick because all source code is already in place. During that set-up, Nginx vhost(s) will be set, Settings.yaml will be updated with database credentials (linked db container) and - if it is Neos - initial Neos admin user will be created and specified site package will be imported. Read below about available ENV variables to customise your setup.

## Usage

As it's shown in [million12/typo3-neos](https://github.com/million12/docker-typo3-neos), you can build your own TYPO3 Neos image with following Dockerfile:

```
FROM million12/typo3-flow-neos-abstract:latest

# ENV: Install following TYPO3 Neos version
ENV T3APP_BUILD_BRANCH 1.1.2

# ENV: Repository for installed TYPO3 Neos distribution 
#ENV T3APP_BUILD_REPO_URL git://git.typo3.org/Neos/Distributions/Base.git

# ENV: Optional composer install parameters
#ENV T3APP_BUILD_COMPOSER_PARAMS --dev --prefer-source

#
# Pre-install TYPO3 Neos into /tmp/typo3-neos.tgz
#
RUN . /build-typo3-neos/pre-install-typo3-neos.sh
```

This will pre-install default TYPO3 Neos distribution, version 1.1.2. Uncomment and provide custom `ENV T3APP_BUILD_REPO_URL` to install your own distribution.

See [README.md](https://github.com/million12/docker-typo3-neos/README.md) from [million12/typo3-neos](https://github.com/million12/docker-typo3-neos) for more information about how to run all required containers (e.g. MariaDB) and have working instance of TYPO3 Neos.

### Testing

With this container, you can run all TYPO3 tests, including Behat tests which requires Selenium server. There is an ENV variable **T3APP_DO_INIT_TESTS** to make this process as easy as possible. When T3APP_DO_INIT_TESTS=true, testing environment and database will be created/configured.

For an example how to run test suites included in TYPO3 Neos, see the [million12/behat-selenium](https://github.com/million12/docker-behat-selenium) repository.

## How does it work

You start with creating a new Docker image based on **million12/typo3-flow-neos-abstract**, using `FROM million12/typo3-flow-neos-abstract:latest` in your Dockerfile. 

#### Build phase

During *build process* of your image, TYPO3 Neos will be pre-installed using `composer install` and embedded inside the image as a tar achive. Using ENV variables (listed below) you can customise pre-install process: provide custom distribution (e.g. from your GitHub repo) or specify different version of TYPO3 Neos. For detailed info about how this pre-install script works, see [pre-install-typo3-neos.sh](container-files/build-typo3-neos/pre-install-typo3-neos.sh).

In addition, if in the root directory of your repository have executable 'build.sh' it will be executed as `build.sh --preinstall`. You can easily add custom build steps there which you want to run during Docker build phase. 

#### Container launched

When you start that prepared container, it will run [configure-typo3-neos.sh](container-files/build-typo3-neos/configure-typo3-neos.sh) script which does all necessary steps to make TYPO3 Neos up & running. 

Here are the details:

##### Nginx vhost config
File [vhost.conf](container-files/build-typo3-neos/vhost.conf) is used as model vhost config. Vhost names are supplied via *T3APP_VHOST_NAMES* env variable. NOTE: currently there's configured redirect to non-www vhost (the 1st one shall you provided more than one).

You can completely override that template file if you need custom configuration. Note that this vhost config file will be overridden/regenerated each time container starts unless you set env variable `T3APP_FORCE_VHOST_CONF_UPDATE=false`.

##### TYPO3 Neos app install
Pre-installed during image build process TYPO3 Neos is unpacked to /data/www/$NEOS\_APP\_NAME and - optionally - git pull is executed (if $NEOS\_APP\_FORCE\_PULL is set to true).

##### Database config
Default Configuration/Settings.yaml is created (if doesn't exist) and updated with DB credentials to linked db container. NEOS\_APP\_DB_NAME is created if it doesn't exist yet.

##### Doctrine migration, site package install
If fresh/empty database is detected, `./flow doctrine:migrate` is perfomed, admin user is created and $NEOS\_APP\_SITE\_PACKAGE is imported. If $NEOS\_APP\_FORCE\_SITE\_REIMPORT is set, site content will be pruned and imported each time container starts.

##### Cache, permissions
Cache is warmed up for Production and Development contexts, filesystem permissions are updated/fixed.

##### Application build.sh
If scripts detects executable `build.sh` in the Neos root directory, it will run it. This is a good place to add custom build steps, like compiling CSS, minifying JS, generating resources etc. Note that this is the same script which is run during Docker build phase (which is then run with `--preinstall` argument).

##### Your own build steps

You might want to add extra steps to the ones provided above. If application's build.sh is not the right place to do it, you can add custom scripts to `/config/init/*.sh`. The image is designed that it runs all scripts from that location when the container starts.


## Customise your image

### Dockerfile

In Dockerfile you can customise what and from where is pre-installed during build stage:   
```
FROM million12/typo3-flow-neos-abstract:latest

# ENV: Install custom Neos version
# Default: master
ENV T3APP_BUILD_BRANCH 1.1.2

# ENV: Repository for installed TYPO3 app
# Default: git://git.typo3.org/Flow/Distributions/Base.git
ENV T3APP_BUILD_REPO_URL https://github.com/you/your-typo3-neos-distro.git

# ENV: Custom composer install params
# Default: --dev --prefer-source
ENV T3APP_BUILD_COMPOSER_PARAMS --no-dev --prefer-dist --optimize-autoloader

# Run pre-install script
RUN . /build-typo3-neos/pre-install-typo3-neos.sh
```

Note the last line with RUN action, which needs to be added by you.


### Accessing private repositories example

To access private repositories, generate a new SSH key set and add the key as deployment key to your private repository. Then you need to embed them inside your image (via `ADD` instruction in the Dockerfile) and configure SSH that they will be used during *git clone*. Your Dockerfile could look as following:
 
```
FROM million12/typo3-flow-neos-abstract:latest

ENV T3APP_BUILD_REPO_URL git@github.com:company/your-private-repo.git

ADD gh-repo-key /
RUN \
  chmod 600 /gh-repo-key && \
  echo "IdentityFile /gh-repo-key" >> /etc/ssh/ssh_config && \
  . /build-typo3-neos/pre-install-typo3-neos.sh
```

## Environmental variables

### Dockerfile variables

These are variables relevant during build process of your custom image:

**T3APP_BUILD_REPO_URL**  
Default: `T3APP_BUILD_REPO_URL=git://git.typo3.org/Flow/Distributions/Base.git`  
By default it points to TYPO3 Flow base distribution. Override it to `git://git.typo3.org/Neos/Distributions/Base.git` to install TYPO3 Neos base distribution. Provide your own repository to install your own Flow/Neos distribution. The repository can be private: read more above for an example how to configure/access private repositories. Remember to use git url in SSH format for private repositories, i.e. *git@github.com:user/package.git*.

**T3APP_BUILD_BRANCH**  
Default: `T3APP_BUILD_BRANCH=master`  
Branch or tag name to checkout. For instance, to install default TYPO3 Neos base distribution, but **stable version**, you might want to override it with `1.1.2`.

**T3APP_BUILD_COMPOSER_PARAMS**  
Default: `T3APP_BUILD_COMPOSER_PARAMS=--dev --prefer-source`  
Extra parameters for `composer install`. You might override it with e.g. `--no-dev --prefer-dist --optimize-autoloader` on production.

### Runtime variables

Following is the list of available ENV variables which can be overridden when container is launched (via --env). You can also embed them in your Dockerfile. See [configure-typo3-neos.sh](container-files/build-typo3-neos/configure-typo3-neos.sh) where they are defined with their default values. 

**T3APP_DO_INIT**  
Default: `T3APP_DO_INIT=true`  
When set to TRUE, TYPO3 Neos will be fully initialised, incl. importing/installing specified site package. It might be useful to set it to FALSE when you only want to run tests against this container and you do not need working site.

**T3APP_DO_INIT_TESTS**  
Default: `T3APP_DO_INIT_TESTS=false`  
When set to TRUE, TYPO3 Neos will be prepared to run unit, functional and behavioral tests out of the box. If you set this option, you have to define vhost behat.dev.[your-base-domain] in *T3APP_VHOST_NAMES* variable. This so-called "Behat vhost" will be used to configure corresponding behat.yml files and will be used for Behat testing.

When this is set to TRUE, an empty database for testing is created, **Development/Behat** and **Testing/Behat** contexts are configured, all `Packages/*/*/Tests/Behavior/behat.yml.dist` are copied to `behat.yml`, with `base_url:` option set to detected "Behat vhost". In addition, `./flow behat:setup` command will be run to prepare all necessary dependencies for running the tests.

For an example how to run all test suites included in TYPO3 Neos, see the [million12/behat-selenium](https://github.com/million12/docker-behat-selenium) repository.

**T3APP_NAME**  
Default: `T3APP_NAME=typo3-app`  
Used internally as a folder name in /data/www/T3APP_NAME where Flow/Neos will be installed and it's used in default vhost name(s) - see `T3APP_VHOST_NAMES` variable.

**T3APP_DB_NAME**  
Default: `T3APP_DB_NAME=${T3APP_DB_NAME:="typo3_app"}`  
Database name, which will be used for TYPO3 Neos. It will be created and migrated, if it doesn't exist.

**T3APP_USER_NAME**  
**T3APP_USER_PASS**  
**T3APP_USER_FNAME**  
**T3APP_USER_LNAME**  
Default: `T3APP_USER_NAME=admin`  
Default: `T3APP_USER_PASS=password`  
Default: `T3APP_USER_FNAME=Admin`  
Default: `T3APP_USER_LNAME=User`  
If this is fresh installation, admin user will be created with above details.

**T3APP_VHOST_NAMES**  
Default: `T3APP_VHOST_NAMES="${T3APP_NAME} dev.${T3APP_NAME} behat.dev.${T3APP_NAME}"`  
Hostname(s) to configure in Nginx. Nginx is configured that it will set `FLOW_CONTEXT` to *Development* if it contains *dev* in its name, *Testing* if it contains *test*.

Note: vhost `behat.dev.${T3APP_NAME}"` is important one if you plan to run Behat test on that container (and you have set T3APP_DO_INIT_TESTS to true). In addition, for that vhost, Nginx sets `Development/Behat` FLOW_CONTEXT (see [vhost.conf](container-files/build-typo3-neos/vhost.conf)).

**T3APP_NEOS_SITE_PACKAGE**  
Default: `T3APP_NEOS_SITE_PACKAGE=false`
The default value is FALSE which means site package will not be installed unless you specify one. For default Base distribution you would specify here `TYPO3.NeosDemoTypo3Org` value. For your own distribution specify your custom site package.

When this value is specified, the site package will be installed and its content imported (if it is a fresh installation and). If you want to re-install / re-import the site content even if it was already installed, set `T3APP_NEOS_SITE_PACKAGE_FORCE_REIMPORT=true` (see below).

**T3APP_NEOS_SITE_PACKAGE_FORCE_REIMPORT**  
Default: `T3APP_NEOS_SITE_PACKAGE_FORCE_REIMPORT=false`  
Set to true to prune (`./flow site:prune`) and re-import (`./flow site:import ...`) site content each time container starts. Useful if you keep your Sites.xml versioned and in sync.

**T3APP_ALWAYS_DO_PULL**  
Default: `T3APP_ALWAYS_DO_PULL=false`  
Set to true to execute `git pull` command inside Neos root directory (preceded by git clean/reset to avoid any potential conflicts). This might be useful to ensure fresh/latest codebase of your app, even if the pre-installed image version is a bit outdated. Note: if you provided $TYPO3\_NEOS\_VERSION which is not a branch, the pull will fail.

**T3APP_FORCE_VHOST_CONF_UPDATE**  
Default: `T3APP_FORCE_VHOST_CONF_UPDATE=true`
When TRUE (which is default), Nginx vhost file will be always overridden with the content from [vhost.conf](container-files/build-typo3-neos/vhost.conf) template. You might override it and keep together with your project files to keep in in sync. If you prefer manual updates, set it to FALSE.

## Authors

Author: Marcin Ryzycki (<marcin@m12.io>)  
