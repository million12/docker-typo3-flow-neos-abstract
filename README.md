# Flow/Neos Docker image
[![Circle CI](https://circleci.com/gh/million12/docker-typo3-flow-neos-abstract/tree/master.svg?style=svg)](https://circleci.com/gh/million12/docker-typo3-flow-neos-abstract/tree/master)

This is a Docker image [million12/typo3-flow-neos-abstract](https://registry.hub.docker.com/u/million12/typo3-flow-neos-abstract) for Flow and [Neos](https://neos.io/) application deployments.

## Features

* Use directly this image for standard Flow/Neos apps.
* Easily create custom image based on this one, to create customised setup.
* Pre-install Flow/Neos app and embed it inside the image to speed up and bullet-proof container lunch process.
* Full customisation via ENV variables, e.g. custom (private) repositories, custom site package.
* [Surf](http://docs.typo3.org/surf/TYPO3SurfDocumentation/) deployment support.
* Custom build scripts, user hooks available for a few installation/configuration steps.
* Ability to run all unit, functional, Behat tests with this image and [million12/php-testing](https://github.com/million12/docker-php-testing).
* PHP-FPM (from parent [million12/nginx-php](https://github.com/million12/docker-nginx-php)), tuned for Flow/Neos applications.  
  Different versions of PHP available in a separate branches: **5.5** (branch php-55, `million12/typo3-flow-neos-abstract:php-55`), **5.6** (master, `million12/typo3-flow-neos-abstract:latest`), **7.0** (branch php-70, `million12/typo3-flow-neos-abstract:php-70`).
* External database fully configurable. Use linked MariaDB container or completely external DB service.
* CI tests to cover functionality of this image.

As you can see, it can be like Homestead (vide [Laravel Homestead](http://laravel.com/docs/master/homestead)) for your Flow or Neos application.


## Usage

#### Use directly `million12/typo3-flow-neos-abstract`

##### Flow example
```
docker run -d --name=db --env="MARIADB_PASS=my-pass" million12/mariadb
docker run -d --name=flow -p=8080:80 --link=db:db \
    --env="T3APP_VHOST_NAMES=flow dev.flow" \
    --env="T3APP_BUILD_REPO_URL=https://git.typo3.org/Flow/Distributions/Base.git" \
    --env="T3APP_BUILD_BRANCH=3.0" \
    million12/typo3-flow-neos-abstract
```
This will install Flow (3.0). After container finished start and you mapped `flow dev.flow` to container IP in your `/etc/hosts`, you can access Flow on http://flow:8080 (or http://dev.flow:8080 for Development context).

Note: in the example we link with `db` container, so `flow` container can read its configuration directly (host, password etc). Otherwise you'd need to provide `T3APP_DB_*` env variables explicitly.

##### Neos example

```
docker run -d --name=db --env="MARIADB_PASS=my-pass" million12/mariadb
docker run -d --name=neos -p=8080:80 --link=db:db \
    --env="T3APP_VHOST_NAMES=neos neos.flow" \
    --env="T3APP_BUILD_REPO_URL=https://git.typo3.org/Neos/Distributions/Base.git" \
    --env="T3APP_BUILD_BRANCH=2.0" \
    million12/typo3-flow-neos-abstract
```
This will install Neos (2.0). After container finished start and you mapped `neos dev.neos` to container IP in your `/etc/hosts`, you can access Flow on http://neos:8080 (or http://dev.neos:8080 for Development context).

#### Build your own image

There are many reasons you'd need to build your own image: you want to install custom distribution from private repository, you want to use pre-install feature, you project needs some custom software embedded in the image, you want to provide default ENV variables more suitable for your app etc.

For an **example of Flow image** built on top of this one, see [million12/typo3-flow](https://github.com/million12/docker-typo3-flow) repository.

For an **example of Neos image** built on top of this one, see [million12/typo3-neos](https://github.com/million12/docker-typo3-neos) repository.

**Community examples:**
* [m12.io](http://m12.io) website. See the [Dockerfile](https://github.com/million12/site-m12-io/tree/master/docker) with an example of custom distribution/site package and example how to access repository using SSH keys, use build user hooks.
* [sfi.ru](http://sfi.ru/) website. See the [Dockerfile](https://github.com/sfi-ru/SfiDistr/tree/master/docker) with an example how to override PHP/ configuration and do Surf deployments. 


## Flow or Neos?

The configuration script detects if it's Flow or Neos installation. When `typo3/neos` is found in `composer.json`, Neos installation is assumed and few extra steps are performed (e.g. site import). See [configure-typo3-app.sh](container-files/build-typo3-app/configure-typo3-app.sh) for details (look for `INSTALLATION_TYPE` variable).

## Host names, FLOW_CONTEXT environment and testing

Be aware that, by default, **`FLOW_CONTEXT` variable is set based on virtual host name** (i.e. Produciton, Development, Testing).

The rules are:
* when vhost contains `dev` in its name, `FLOW_CONTEXT=Development`.
* when vhost contains `dev` and `behat` in its name, `FLOW_CONTEXT=Developmnet/Behat`
* all other cases: `FLOW_CONTEXT=Production`.

With that it's easy to use the [default provided Nginx configuration](container-files/build-typo3-app/vhost.conf) and have your production website on `site.com` domain, `dev.site.com` for your developers and possibly e.g. `behat.dev.site.com` to run Behat tests. 

With this container, you can run all unit, functional tests, including Behat tests which requires Selenium server. There is an ENV variable **T3APP_DO_INIT_TESTS** to make this process painless. When T3APP_DO_INIT_TESTS=true, testing environment and database will be created/configured. See the section about env variables below for more info.

For the example how to run test suites included in Neos using this container, see the [million12/php-testing](https://github.com/million12/docker-php-testing) repository. For even more info see the [Neos testing documentation](http://docs.typo3.org/neos/TYPO3NeosDocumentation/DeveloperGuide/Testing/Index.html) website.


## How does it work

You start with creating a new Docker image based on **million12/typo3-flow-neos-abstract**, using `FROM million12/typo3-flow-neos-abstract` in your Dockerfile. 

#### Build phase

Optionally, Flow/Neos app can be pre-installed (git clone + composer install) during `docker build` and embedded within the image. That gives a much faster container start (seconds instead of minutes). It also makes the container starts insensitive to outside circumstances, e.g. network issues, timeouts, repository rate limits etc.

You can customise the pre-install process using ENV variables listed below. You can provide custom distribution URL (e.g. from your GitHub repo) or specify different branch/tag. For detailed info about how this pre-install script works, see [pre-install-typo3-app.sh](container-files/build-typo3-app/pre-install-typo3-app.sh).

To use this feature, you need to add your Dockerfile line:  
`RUN . /build-typo3-app/pre-install-typo3-app.sh`
(just after `ADD container-files /` line).

#### Container lunch

When you start the container, it will run [configure-typo3-app.sh](container-files/build-typo3-app/configure-typo3-app.sh) script which does all necessary steps to make TYPO3 Flow/Neos up & running.

Here are the details:

##### Nginx vhost config
File [vhost.conf](container-files/build-typo3-app/vhost.conf) is used as a model vhost config. Vhost names are supplied via *T3APP_VHOST_NAMES* env variable. NOTE: currently there is configured redirect to non-www vhost (the 1st one, shall you provided more than one).

You can completely override that template file if you need custom configuration. Note that this vhost config file will be overridden/regenerated each time container starts unless you set env variable `T3APP_FORCE_VHOST_CONF_UPDATE=false`.

##### Actual application install
If the app was pre-installed during the image build process, it will be unpacked to /data/www/$T3APP_NAME and - optionally - git fetch/pull is executed (if `T3APP_ALWAYS_DO_PULL` is set to true).

In case of not using pre-install feature, it will be installed (git checkout, composer install).

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
Path to custom build hook script which is executed during major points of the build and run phase. The path is relative to the project root directory. See [User hooks](#User hooks) section for more information about how to use it and what hooks are available.

**T3APP_USE_SURF_DEPLOYMENT**  
Default: `T3APP_USE_SURF_DEPLOYMENT=false`  
Set to TRUE to use directory layout compatible with Surf.

**T3APP_SURF_SMOKE_TEST_DOMAIN**  
Default: `T3APP_SURF_SMOKE_TEST_DOMAIN=next.<the 1st domain from $T3APP_VHOST_NAMES>`  
If you use `T3APP_USE_SURF_DEPLOYMENT`, this is the extra domain which will be configured in Nginx (and aliased to 127.0.0.1 inside container). It's needed if you want to use Surf smoke test task `typo3.surf:test:httptest`.

### Other (runtime/internal) variables

These are variables which are set internally when container starts. You might want to use them e.g. inside your site build hook script (see `T3APP_USER_BUILD_SCRIPT`).

**RUNTIME_EXECUTED_MIGRATIONS**  
Contains number of executed db migrations (from `flow doctrine:migrationstatus`). Useful to detect fresh installs e.g. in your own `T3APP_USER_BUILD_SCRIPT`.
```
if [[ $RUNTIME_EXECUTED_MIGRATIONS == 0 ]]; then
    do_something
fi
```

### User hooks

If present, custom `build.sh` script (name/path defined in `T3APP_USER_BUILD_SCRIPT` env variable) might be executed during major points of the build and run phase. This is very useful if you need to add custom steps to do while your app is bootstrapping, e.g. add extra configuration, sync the content, do front-end Grunt/Gulp tasks etc.

Key things to know:
* Hook script is executed as `<T3APP_USER_BUILD_SCRIPT> <hook-name>`, e.g. `./build.sh --post-build`.
* The hook script is always executed as a `root` user. If you need something to be run as `www` user (Nginx and PHP-FPM run as `www` user), write something like this: `su www -c "my command here"`.
* There's very simple check to determine if the hook should be run. If the hook script contains hook name (e.g. `--post-build`) in its content, it will be run. Otherwise not.

##### List of available user hooks

* **`--post-build`**: called at the end of `docker-build` phase, just after initial composer install. Note: in previous version of this package it was called `--preinstall`, which still works for backward-compatibility reasons, but it will be removed in future versions.  
  **Example usage:** ideal place to install any software needed for your project. It will be added to built Docker image.

* **`--post-install`**: Flow/Neos app (source code) has been installed, but application is not yet fully initialised (Settings.yaml not configured, DB not migrated, site package not installed).

* **`--post-settings`**: Settings.yaml is configured with DB credentials (TYPO3.Flow.persistence.backendOptions). Note: at this stage you have access to runtime variable, `RUNTIME_EXECUTED_MIGRATIONS` (see above).  
  Ideal place to do extra configuration of Settings.yaml.

* **`--post-db-migration`**: Database has been migrated/provisioned, but it's still empty (no user, no site package yet)

* **`--pre-cache-warmup`**: Flow or Neos app is fully initialised, but caches haven't been warmed up yet.

* **`--post-init`**: application is fully initialised, incl. warmed up caches for `Production` context. If you set `T3APP_DO_INIT_TESTS=TRUE`, this hook is called *before* Behat tests will be initialised.

* **`--post-test-init`**: called after Behat tests are fully initialised. Only active when `T3APP_DO_INIT_TESTS=TRUE`.

* **`[no param]`**: Called at the very end of bootstrap process during `docker run` phase. Application is fully initialised, but web server didn't started yet. It will start after your script finishes execution.  
  **Example usage:** ideal place to run any Gulp/Grunt tasks, i.e. CSS post-processing, JS minification etc.

##### Example user hook script

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
  # This is called at the end of `docker build` phase.
  #
  *--post-build*)
    # Install some tools required by project
    npm install -g gulp bower
    ;;
 
  #
  # This is called when container launches (and the script is called without param)
  #
  *)
    cd Build/
    bower install --allow-root
    npm install
    gulp build --env=Production
    ;;
esac
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
Database name, which will be used for the application. It will be created (if does not exist) and migrated (for fresh installations). Note: all non-allowed in db identifiers characters will be replaced with `_` char when using the db name from `T3APP_NAME` value (which might contain e.g. `-` chars).

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


## Production usage

This image is not only perfect for development purposes, it's **production ready**. There are handful of projects where people use it on production:
* [m12.io](http://m12.io/)
* [sfi.ru](http://sfi.ru/)
* [typostrap.io](https://typostrap.io/) and [tstr.io](https://tstr.io/)


## Authors

* Marcin 'ryzy' Ryzycki (<marcin@m12.io>)
* Dmitri Pisarev (<dimaip@gmail.com>)

---

**Sponsored by** [Typostrap.io - the new prototyping tool](http://typostrap.io/) for building highly-interactive prototypes of your website or web app. Built on top of Neos CMS and Zurb Foundation framework.
