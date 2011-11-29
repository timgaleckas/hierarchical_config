## What is it

HierarchicalConfig is a library that implments a strategy for configuring an application in a static, declarative, robust, and intuitive way

## Principles

1. You should not be able to change your config once it's loaded. That's
   not configuration, that's globals.
2. You should be able to check in to source control a config file that
   holds defaults and defines requirements.
3. You should be able to define defaults accross multiple environments
   without repeating yourself.
4. You should be able to change configuration per box based on deploy
   that does not affect the defaults or requirements that are checked in
   to source control.

## Usage

1. require 'hierarchical_config'
2. MY_APP_CONFIG = HierarchicalConfig.load_config( 'config_name', 'config_directory', 'environment_name' )

## How does it work

HierarchicalConfig loads a yaml file from the config directory. Each top
level name in the yaml file is either a default stanza (for one or more
environments,) or a specific environment.

It applies least specific rules first and proceeds to most specific. It
then reads an optional overrides file and does the same. If any REQUIRED
values have not been overriden by actual values, it raises an exception.

The object that it returns is a deeply nested tree of configuration that
can't be modified and raises exceptions if you ask for values that it
doesn't know about.

* No more having environments load without the mail server address
  configured.
* No more silent failures and returning nil for something you thought
  was configured.
* No more copy and pasting configuration accross environments.
* No more stupid YAML tricks to dry up your configuration.
* No more tricky config that changes based on runtime side effects.
* No more config that is hidden from developers and not in source
  control (unless you specifically need to.)

## Example

### config/app.yml

    defaults:
      root:
        child_a: 1
        child_b: 2
        child_c:
          grandchild_a: 3
          grandchild_b: 4
      super_secret_password: !REQUIRED

    defaults[development,test]:
      super_secret_password: not_that_secret

    development:
      root:
        child_b: 8

### config/app-overrides.yml

    production:
      super_secret_password: cant_trust_dev_with_this_we_symlink_this_file

## Results

### development

    :root: 
      :child_a: 1
      :child_b: 8
      :child_c: 
        :grandchild_a: 3
        :grandchild_b: 4
    :super_secret_password: not_that_secret

### test

    :root: 
      :child_a: 1
      :child_b: 2
      :child_c: 
        :grandchild_a: 3
        :grandchild_b: 4
    :super_secret_password: not_that_secret

### production

    :root: 
      :child_a: 1
      :child_b: 2
      :child_c: 
        :grandchild_a: 3
        :grandchild_b: 4
    :super_secret_password: cant_trust_dev_with_this_we_symlink_this_file

### staging

    RuntimeError: ["app.super_secret_password is REQUIRED for staging"]
