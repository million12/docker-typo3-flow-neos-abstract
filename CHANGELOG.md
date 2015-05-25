## [not released yet]

- FEATURE: Surf deployment support
- FEATURE: more user hooks (see README)
- **!!!** File `/etc/nginx/conf.d/typo3-flow-rewrites.conf`  
  has been renamed to `/etc/nginx/conf.d/flow-rewrites.conf`.  
  This is a breaking change in case you've overridden default `vhost.conf` provided with this image.
- Improved composer configuration within container (process-timeout=1800, discard-changes=true)

## 0.3.0 (2015-03-01)

- Feature: Allow switching between branches using T3APP_BUILD_BRANCH
- Feature: All env variables for DB connection nicely exposed, instead of relying that the container is always linked to DB container with particular name.
- Feature: Make pre-installing the app to archive optional
- **!!!** More robust T3APP_ALWAYS_DO_PULL behaviour
- Flow rewrite rules compatible with Flow 3.0 and Neos 2.0.
- FLOW_CONTEXT configuration based on hostnames explained in README. Setting Testing Flow context removed from Nginx vhosts as it's not used anyway (FLOW_CONTEXT=Testing is only used internally when running functional tests from CLI).
- FIX for db collation: now by default utf8_unicode_ci. Also, ./flow database:setcharset is always executed when container starts.
- **!!!** Switch to parent image million12/nginx-php (was: million12/php-app).

## 0.2.0 (2015-01-09)

- FEATURE: support for both Flow and Neos
- FEATURE: ability to skip site package installation (NEOS_APP_SITE_PACKAGE, false by default)
- IMPROVEMENT: .bash_profile for 'www' user, T3APP_VHOST_NAMES added to /etc/hosts
- FEATURE: `RUNTIME_EXECUTED_MIGRATIONS` exposed to use in site's build script
- Misc cosmetic improvements/fixes

## 0.1.0 (2014-11-09)

- First stable version

## 0.0.1 (2014-09-16)

- Initial version
