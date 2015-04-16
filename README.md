# TYPO3 Flow/Neos | Abstract Docker image
[![Circle CI](https://circleci.com/gh/million12/docker-typo3-flow-neos-abstract/tree/master.png?style=badge)](https://circleci.com/gh/million12/docker-typo3-flow-neos-abstract/tree/master)

This is a Docker image [million12/typo3-flow-neos-abstract](https://registry.hub.docker.com/u/million12/typo3-flow-neos-abstract) which is **designed to easily create images with standard or customised installation** of [TYPO3 Flow](http://flow.typo3.org/) or [TYPO3 Neos](http://neos.typo3.org/). Your image can be build from  either the default "base" distribution or your own, perhaps private, repository. 

For an **example of TYPO3 Flow image** built on top of this one, see [million12/typo3-flow](https://github.com/million12/docker-typo3-flow) repository.

For an **example of TYPO3 Neos image** built on top of this one, see [million12/typo3-neos](https://github.com/million12/docker-typo3-neos) repository.

The image is designed that after running a container from it, you'll get working TYPO3 Flow/Neos in a matter of seconds. To achieve that, when the image is being build, it pre-installs (via `composer install`) requested version of TYPO3 Flow/Neos into /tmp location (and all its dependencies). Later on, when the container is run, it will initialise and configure that pre-installed package. This process is very quick because all source code is already in place. During that set-up, Nginx vhost(s) will be set, Settings.yaml will be updated with database credentials (see [Database connection](#database-connection) section), database will be migrated and - if it is Neos - initial Neos admin user will be created and specified site package will be imported. Read below about available ENV variables to customise your setup.

## Flow or Neos installation

The configuration script tries to detect if it is a Flow or Neos installation. It simply test main `composer.json` for `typo3/neos` string and, if it is found, sets the installation type to `neos`. See [configure-typo3-app.sh](container-files/build-typo3-app/configure-typo3-app.sh) for details (look for `INSTALLATION_TYPE` variable).

## Host names, FLOW_CONTEXT environment and testing

Be aware that, by default, **`FLOW_CONTEXT` variable is set based on virtual host name** (i.e. Produciton, Development, Testing).

The rules are:
* when vhost contains `dev` in its name, `FLOW_CONTEXT=Development`.
* when vhost contains `dev` and `behat` in its name, `FLOW_CONTEXT=Developmnet/Behat`
* all other cases: `FLOW_CONTEXT=Production`.

With that it's easy to use the [default provided Nginx configuration](container-files/build-typo3-app/vhost.conf) and have your production website on `site.com` domain, `dev.site.com` for your developers and possibly e.g. `behat.dev.site.com` to run Behat tests. 

With this container, you can run all TYPO3 tests, including Behat tests which requires Selenium server. There is an ENV variable **T3APP_DO_INIT_TESTS** to make this process painless. When T3APP_DO_INIT_TESTS=true, testing environment and database will be created/configured. See the section about env variables below for more info.

For the example how to run test suites included in TYPO3 Neos using this container, see the [million12/behat-selenium](https://github.com/million12/docker-behat-selenium) repository. For even more info see the [TYPO3 Neos testing documentation](http://docs.typo3.org/neos/TYPO3NeosDocumentation/DeveloperGuide/Testing/Index.html) website.

## Usage

As it's shown in [million12/typo3-neos](https://github.com/million12/docker-typo3-neos), you can build your own TYPO3 Neos image with following Dockerfile:

```
FROM million12/typo3-flow-neos-abstract:latest

# ENV: Install following TYPO3 Neos version
ENV T3APP_BUILD_BRANCH 1.1.2

# ENV: Repository for installed TYPO3 Neos distribution 
ENV T3APP_BUILD_REPO_URL git://git.typo3.org/Neos/Distributions/Base.git

# ENV: Optional composer install parameters
#ENV T3APP_BUILD_COMPOSER_PARAMS --dev --prefer-source

#
# Pre-install TYPO3 Neos into /tmp location
#
RUN . /build-typo3-app/pre-install-typo3-app.sh
```

This will pre-install default TYPO3 Neos distribution, version 1.1.2. Uncomment and provide custom `ENV T3APP_BUILD_REPO_URL` to install your own distribution.

See [README.md](https://github.com/million12/docker-typo3-neos/README.md) from [million12/typo3-neos](https://github.com/million12/docker-typo3-neos) for more information about how to run all required containers (e.g. MariaDB) and have working instance of TYPO3 Neos.

## How does it work

You start with creating a new Docker image based on **million12/typo3-flow-neos-abstract**, using `FROM million12/typo3-flow-neos-abstract:latest` in your Dockerfile. 

#### Build phase

During *build process* of your image, TYPO3 app will be pre-installed using `composer install` and embedded inside the image as a tar achive. Using ENV variables (listed below) you can customise pre-install process: provide custom distribution (e.g. from your GitHub repo) or specify different branch/tag. For detailed info about how this pre-install script works, see [pre-install-typo3-app.sh](container-files/build-typo3-app/pre-install-typo3-app.sh).
It is posible to not use pre-installed app and compose app on first container start with setting `T3APP_PREINSTALL` variable to false (and not calling `RUN . /build-typo3-app/pre-install-typo3-app.sh` your image).

In addition, if in the root directory of your project you have executable `build.sh` it will be executed as `build.sh --preinstall`. You can easily add custom build steps there which you want to run during Docker build phase. See `T3APP_USER_BUILD_SCRIPT` variable where you can customise path to that script.

#### Container launched

When you start that prepared container, it will run [configure-typo3-app.sh](container-files/build-typo3-app/configure-typo3-app.sh) script which does all necessary steps to make TYPO3 Flow/Neos up & running. 

Here are the details:

##### Nginx vhost config
File [vhost.conf](container-files/build-typo3-app/vhost.conf) is used as a model vhost config. Vhost names are supplied via *T3APP_VHOST_NAMES* env variable. NOTE: currently there is configured redirect to non-www vhost (the 1st one, shall you provided more than one).

You can completely override that template file if you need custom configuration. Note that this vhost config file will be overridden/regenerated each time container starts unless you set env variable `T3APP_FORCE_VHOST_CONF_UPDATE=false`.

##### TYPO3 app install
TYPO3 app which was pre-installed during the image build process is unpacked to /data/www/$T3APP_NAME and - optionally - git pull is executed (if `T3APP_ALWAYS_DO_PULL` is set to true).

##### Database config
Default Configuration/Settings.yaml is created (if doesn't exist) and updated with DB credentials. Read on [Database connection](#database-connection) section for more info. Database `T3APP_DB_NAME` is created if it does not exist yet.

##### Doctrine migration, site package install
If fresh/empty database is detected, `./flow doctrine:migrate` is performed. For Neos installation additional steps are required: admin user is created and `T3APP_NEOS_SITE_PACKAGE` is imported. If `T3APP_NEOS_SITE_PACKAGE_FORCE_REIMPORT` is set to TRUE, site content will be pruned/imported each time container starts.

##### Cache, permissions
Cache is warmed up for Production context, filesystem permissions are set.

##### Application build.sh
You can provide an extra `build.sh` script in the project's root directory which will be run at the end of setup process. This is a good place to add custom build steps, like compiling CSS, minifying JS, generating resources etc. Note that this is the same script which is run during Docker build phase (which is then run with `--preinstall` argument). See `T3APP_USER_BUILD_SCRIPT` env variable to override path to this build.sh script.


## Customise your image

### Dockerfile

In Dockerfile you can customise what and from where is pre-installed during build stage:   
```
FROM million12/typo3-flow-neos-abstract:latest

# ENV: Install custom Flow version
# Default: master
ENV T3APP_BUILD_BRANCH 2.2.2

# ENV: Repository for installed TYPO3 app
# Default: git://git.typo3.org/Flow/Distributions/Base.git
ENV T3APP_BUILD_REPO_URL https://github.com/you/your-typo3-flow-app.git

# ENV: Custom composer install params
# Default: --dev --prefer-source
ENV T3APP_BUILD_COMPOSER_PARAMS --no-dev --prefer-dist --optimize-autoloader

# Run pre-install script
RUN . /build-typo3-app/pre-install-typo3-app.sh
```


### Accessing private repositories example

To access private repositories, generate a new SSH key set (e.g. `ssh-keygen -q -t rsa -N '' -f gh-repo-key`) and add the generated key as deployment key to your private repository. Then you need to embed it inside your image (via `ADD` instruction in the Dockerfile) and configure SSH client so that it will be used during *git clone*. Your Dockerfile could look as following:
 
```
FROM million12/typo3-flow-neos-abstract:latest

ENV T3APP_BUILD_REPO_URL git@github.com:company/your-private-repo.git

ADD gh-repo-key /
RUN \
  chmod 600 /gh-repo-key && \
  echo "IdentityFile /gh-repo-key" >> /etc/ssh/ssh_config && \
  . /build-typo3-app/pre-install-typo3-app.sh
```

## Environmental variables

All variables and their defaults are defined in [include-variables.sh](container-files/build-typo3-app/include-variables.sh). Read on to know what are they for. 

Note: the default values are **on purpose not defined in Dockerfile** as defining them would add several new layers to the filesystem in the final Docker image. 

### Build variables

These are variables relevant during build process of your custom image:

**T3APP_BUILD_REPO_URL**  
Default: `T3APP_BUILD_REPO_URL=git://git.typo3.org/Flow/Distributions/Base.git`  
By default it points to TYPO3 Flow base distribution. Override it to `git://git.typo3.org/Neos/Distributions/Base.git` to install TYPO3 Neos base distribution. Provide your own repository to install your own Flow/Neos distribution. The repository can be private: read more above for an example how to configure/access private repositories. Remember to use git url in SSH format for private repositories, i.e. *git@github.com:user/package.git*.

**T3APP_BUILD_BRANCH**  
Default: `T3APP_BUILD_BRANCH=master`  
Branch or tag name to checkout during pre-install phase. For instance, to install default TYPO3 Neos base distribution, but one of stable or older version, you might want to override it with e.g. `1.1.2`.

**T3APP_BUILD_COMPOSER_PARAMS**  
Default: `T3APP_BUILD_COMPOSER_PARAMS=--dev --prefer-source`  
Extra parameters for `composer install`. You might override it with e.g. `--no-dev --prefer-dist --optimize-autoloader` on production.

### Runtime variables

Following is the list of available ENV variables relevant during runtime phase (`docker run`). You can embed them in Dockerfile as well as provide via `--env` param to `docker run` command.

**T3APP_DO_INIT**  
Default: `T3APP_DO_INIT=true`  
When set to TRUE (default), TYPO3 app will be fully configured and set up, incl. db migration and importing/installing specified site package (Neos only). It might be useful to set it to FALSE when you only want to run tests against this container and you do not need working site.

**T3APP_DO_INIT_TESTS**  
Default: `T3APP_DO_INIT_TESTS=false`  
Configure TYPO3 app for running Behat tests. You need to have `flowpack/behat` installed in your `composer.json`.

When you set this option to TRUE, you have to add extra vhost in format `behat.dev.[your-base-domain]` in *T3APP_VHOST_NAMES* variable. This so-called "Behat vhost" will be added to all behat.yml files across all packages and will be used for Behat testing; also it will be used to set proper `FLOW_CONTEXT` for that vhost.

When this option is set to TRUE, an empty database for Behat testing is created and configured for **Development/Behat** and **Testing/Behat** contexts, all `Packages/*/*/Tests/Behavior/behat.yml.dist` are copied to `behat.yml`, with `base_url:` option set to *Behat vhost*. In addition, `./flow behat:setup` command will be run to prepare all necessary dependencies for running the tests.

Note: You *don't* have to set this option to run unit and/or functional tests. Unit and functional tests work out of the box (technical background: functional tests run in `Testing` context, which is out-of-box configured to use `pdo_sqlite` with in-memory tables).

For an example how to run all Behat test suites included in TYPO3 Neos, see the [circle.yml](circle.yml) which contains example of running Behat tests.

**T3APP_NAME**  
Default: `T3APP_NAME=typo3-app`  
Used internally as a folder name in /data/www/T3APP_NAME where Flow/Neos will be installed. It might be also used as a base for vhost name(s) if `T3APP_VHOST_NAMES` is not set.

**T3APP_VHOST_NAMES**  
Default: `T3APP_VHOST_NAMES="${T3APP_NAME} dev.${T3APP_NAME} behat.dev.${T3APP_NAME}"`  
Hostname(s) to configure in Nginx. Nginx is configured that it will set `FLOW_CONTEXT` to *Development* if it contains *dev* in its name, *Testing* if it contains *test*.

Note: vhost `behat.dev.${T3APP_NAME}"` is important one if you plan to run Behat test on that container (and you have set T3APP_DO_INIT_TESTS to true). In addition, for that vhost, Nginx sets `Development/Behat` FLOW_CONTEXT (see [vhost.conf](container-files/build-typo3-app/vhost.conf)).

**T3APP_USER_NAME**  
**T3APP_USER_PASS**  
**T3APP_USER_FNAME**  
**T3APP_USER_LNAME**  
Default: `T3APP_USER_NAME=admin`  
Default: `T3APP_USER_PASS=password`  
Default: `T3APP_USER_FNAME=Admin`  
Default: `T3APP_USER_LNAME=User`  
Neos installation only. If this is fresh installation, admin user will be created with above details.

**T3APP_NEOS_SITE_PACKAGE**  
Default: `T3APP_NEOS_SITE_PACKAGE=false`
Neos installation only. The default value is FALSE which means site package will not be installed unless you specify one. For default Base distribution you would specify here `TYPO3.NeosDemoTypo3Org` value. For your own distribution specify your custom site package.

When this value is specified, the site package will be installed and its content imported (if it is a fresh installation). If you want to re-install / re-import the site content even if it was already installed, set `T3APP_NEOS_SITE_PACKAGE_FORCE_REIMPORT=true` (see below).

**T3APP_NEOS_SITE_PACKAGE_FORCE_REIMPORT**  
Default: `T3APP_NEOS_SITE_PACKAGE_FORCE_REIMPORT=false`  
Neos installation only. Set to true to prune (`./flow site:prune`) and re-import (`./flow site:import ...`) site content each time container starts. Useful if you keep your Sites.xml versioned and in sync.

**T3APP_ALWAYS_DO_PULL**  
Default: `T3APP_ALWAYS_DO_PULL=false`  
When *true*, the newest codebase will be pulled using `git pull` when container starts (preceeded by `git clean, git reset` to avoid any potential conflicts). It is *false* by default as it seems to be more safe during development to avoid loosing any code changes, but it's useful to set it to *true* to ensure fresh/latest codebase of your app. Note: if you provided `T3APP_BUILD_BRANCH` which is not a *branch* but a *tag*, the pull will fail.

**T3APP_FORCE_VHOST_CONF_UPDATE**  
Default: `T3APP_FORCE_VHOST_CONF_UPDATE=true`
When TRUE (which is default), Nginx vhost file will be always overridden with the content from [vhost.conf](container-files/build-typo3-app/vhost.conf) template. You might override it and keep together with your project files to keep in in sync. If you prefer manual updates, set it to FALSE.

**T3APP_USER_BUILD_SCRIPT**  
Default: `T3APP_USER_BUILD_SCRIPT=./build.sh`  
Path to custom build script which is executed at the end of image build phase (with `--preinstall` flag) and at the end of setup process when container is started. The path is relative to the project's root directory and the file needs to be executable.

Here is example script. Note: the `--preinstall` section is executed during container build process and it is **run as super user**. Therefore it is OK to run here command which require extra privileges and you must run them without `sudo` (as there is no sudo command in the container).
``` bash
#!/bin/sh
#
# Site build script
#
# This file should contain all necessary steps to build the website. Include here 
# all necessary build steps (e.g. scripts minification, styles compilation etc).
#

case $@ in
  #
  # This is called when container is being build (and this script is called with --preinstall param)
  #
  *--preinstall*)
    # Install required tools globally
    npm install -g gulp bower
    
    # Install site packages
    set -e # exit with error if any of the following fail
    cd Build/
    bower install --allow-root
    npm install
    gulp build --env=Production
    ;;
 
  #
  # This is called when container launches (and script is called without param)
  #
  *)
    cd Build/
    bower install
    npm install
    gulp build --env=Production # build for production by default
    ;;
esac
```

### Other (runtime/internal) variables

These are variables which are set internally when container starts. You might want to use them e.g. inside your site's build script (see `T3APP_USER_BUILD_SCRIPT` env var).

**RUNTIME_EXECUTED_MIGRATIONS**  
Contains number of executed db migrations (from `flow doctrine:migrationstatus`). Useful to detect fresh installs in site's build script.
```
if [[ $RUNTIME_EXECUTED_MIGRATIONS == 0 ]]; then
    do_something
fi
```

### Database connection

The easiest setup is to link the container with db container, as shown in [Flow](https://github.com/million12/docker-typo3-flow) and [Neos](https://github.com/million12/docker-typo3-neos) container examples:
```
docker run -d --name=db-container --env="MARIADB_PASS=my-pass" million12/mariadb
docker run -d --name=neos -p=8080:80 --link=db-container:db --env="T3APP_VHOST_NAMES=neos dev.neos" million12/typo3-neos
```
We relay on the fact, that `docker run --link=db-container:db` creates all necessary ENV variables inside our container  and necessary entry in `/etc/hosts` (i.e. `DB_CONTAINER_IP_ADD db` which gives you ability to connect to `db` hostname inside the container), so the connection just works.

If you need more flexible setup, customise it with the following ENV variables.

**T3APP_DB_NAME**  
Default: `T3APP_DB_NAME=${T3APP_NAME}`  
Database name, which will be used for TYPO3 app. It will be created (if does not exist) and migrated (for fresh installations). Note: all non-allowed in db identifiers characters will be replaced with `_` char when using the db name from `T3APP_NAME` value (which might contain e.g. `-` chars).

**T3APP_DB_HOST**  
Default: `T3APP_DB_HOST=db`  
Database hostname.

**T3APP_DB_PORT**  
Default: `T3APP_DB_PORT=3306`  
Database port number.

**T3APP_DB_USER**  
Default: `T3APP_DB_USER=admin`  
Database username, which will be used for the connection. This user must have permissions to *create* the `T3APP_DB_NAME` database, if it doesn't exist yet.

**T3APP_DB_PASS**  
Default: `T3APP_DB_PASS=password`


## Authors

Author: Marcin Ryzycki (<marcin@m12.io>)  

---

**Sponsored by** [Typostrap.io - the new prototyping tool](http://typostrap.io/) for building highly-interactive prototypes of your website or web app. Built on top of TYPO3 Neos CMS and Zurb Foundation framework.
