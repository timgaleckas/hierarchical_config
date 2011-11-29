	  !!!plain
                 _                           ____
                | |                         / __/
      __ _ _   _| |_  ___   ___  ___  _ __ | |_ _  __ _
     / _` | | | | __|/ _ \ / __|/ _ \| '_ \|  _| |/ _` |
    | (_| | |_| | |_| (_) | (__| (_) | | | | | | | (_| |
     \__,_|\__,_|\__|\___/ \___|\___/|_| |_|_| |_|\__, |
                                                   __/ |
                                                  |___/

## What is it

`autoconfig` in an automated way to create flexible configuration structures. 

Since version 2.0.0 `autoconfig` relies on [heirarchical_config](https://rubygems.org/gems/hierarchical_config) for the strategy for configuring an application in a static, declarative, robust, and intuitive way.

## Usage

1. require 'autoconfig'
2. profit!

## Basic Example

Lets say you have application.yml in your config folder:

    defaults:
      web:
        hostname: 'localhost'
      noreply: noreply@myhost.com
      support_email: support@myhost.com
    production:
       web:
         hostname: "the.production.com"

After requiring 'autoconfig' you should expect `ApplicationConfig` structure that will contain all the information. 
In production environment `ApplicationConfig.web.hostname` call will return `the.production.com`.

## Advance Example

Check it out under test/config/one

    defaults:
      one: !REQUIRED
      two: two
      three: three
      cache_classes: true
      tree1:
        tree2: hey
        tree3:
          tree4: blah

    defaults[test,cucumber,development]:
      cache_classes: false

    defaults[test,cucumber]:
      one: one

    development:
      one: yup

    test:
      something: hello
      tree1:
        tree3:
          tree4: bleh

    production:
      three: five

Autoconfig can support:

 * specifying which keys are required via !REQUIRED yaml type
 * environment specific defaults shared across some environments
 * deep nested structures

## Configuration

By default, it will look at config directory of your project and transfer most of your .yml files (it ignores database ones). However,
you have full control over where it needs to look and what it needs to convert. Here is a set of environment flags you could use:

 * `AUTOCONFIG_ROOT` - allows setting of the application root. By default it will try to use APP_ROOT, rails root (if rails app) or pwd directory.
 * `AUTOCONFIG_PATERN` - used to construct a path to your configuration files. By default it is set to config/*.yml
 * `AUTOCONFIG_PATH` - allows setting a path to your configuration files. If set autoconfig will ignore patern and root, otherwise
 it look at root and patern to get path to your files.
 * `AUTOCONFIG_ENV` - allows setting environment in which autoconfig runs, by default it will try to use APP_ENV, Rails.env(if rails app) or
 development (in that order)
 * `AUTOCONFIG_IGNORE` - when set it will not create configs for files in the ignore. When not set it will just ignore database.yml. Takes a whitespace
 separated list. Ex: 'cucumber cache'
