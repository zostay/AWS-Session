NAME
====

AWS::Session - Common data useful for accessing and configuring AWS APIs

SYNOPSIS
========

    use AWS::Session;

    my $session      = AWS::Session.new(
        profile => 'my-profile',
    );

    my $profile      = $session.profile;
    my $region       = $session.region;
    my $data-path    = $session.data-path;
    my $config-file  = $session.config-file;
    my $ca-bundle    = $session.ca-bundle;
    my %api-versions = $session.api-versions;
    my $cred-file    = $session.credentials-file;
    my $timeout      = $session.metadata-service-timeout;
    my $attempts     = $session.metadata-service-num-attempts;

    # Read the AWS configuration file
    my %config       = $session.get-configuration;
    my %profile-conf = $session.get-profile-configuration('default');
    my %current-conf = $session.get-current-configuration;

    # Read the AWS credentials file
    my %cred         = $session.get-credentials;
    my %profile-cred = $session.get-profile-credentials('default');
    my %current-cred = $session.get-current-credentials;

DESCRIPTION
===========

AWS clients share some common configuration data. This is a configurable module for loading that data.

ATTRIBUTES
==========

Any attributes provided will override any configuration values found on the system through the environment, configuration, or defaults.

profile
-------

The configuration files are in INI format. These are broken up into sections. Each section is a profile. This way you can have multiple AWS configurations, each with its own settings and credentials.

region
------

This is the AWS region code to use.

data-path
---------

The botocore system uses data models to figure out how to interact with AWS APIs. This is the path where additional models can be loaded.

config-file
-----------

This is the location of the AWS configuration file.

ca-bundle
---------

This is the location of the CA bundle to use.

api-versions
------------

This is a hash of API versions to prefer for each named API.

credentials-file
----------------

This is the location of the credentials file.

metadata-service-timeout
------------------------

This is the timeout to use with the metadata service.

metadata-service-num-attempts
-----------------------------

This is the number of attempts to make when using the metadata service.

session-configuration
---------------------

This is a map of configuration variable names to [AWS::Session::Default](AWS::Session::Default) objects, which define how to configure them.

HELPERS
=======

AWS::Session::Default
---------------------

This is a basic structural class. All attributes are optional.

### ATTRIBUTES

#### config-file

This is the name of the variable to use when loading the value from the configuration file.

#### env-var

This is an array of names of the environment variable to use for the value.

#### default-value

This is the default value to fallback to.

#### converter

This is a function that will convert values from the configuration file or environment variable to the appropriate object.

METHODS
=======

get-configuration
-----------------

    method get-configuration($config-file?, :$reload?) returns Hash

Returns the full contents of the configuration as a hash of hashes. Normally, this method caches the configuration. Setting the `:reload` flag will force the configuration cache to be ignored.

get-profile-configuration
-------------------------

    method get-profile-configuration(Str:D $profile, :$config-file?) returns Hash

Returns the named profile configuration.

get-current-configuration
-------------------------

    method get-current-configuration() returns Hash

Returns the configuration for the current profile.

get-credentials
---------------

    method get-credentials($credentials-file?) returns Hash

Returns the full contents of the credentials file as a hash of hashes. Unlike configuration, the contents of this file is not cached.

get-profile-credentials
-----------------------

    method get-profile-credentials(Str:D $profile, :$credentials-file?) returns Hash

Returns the named profile credentials.

get-current-credentials
-----------------------

    method get-current-credentials() returns Hash

Returns the credentials for the current profile.

get-config-variable
-------------------

    method get-config-variable(
        Str $logical-name,
        Bool :$from-instance = True,
        Bool :$from-env = True,
        Bool :$from-config = True,
    )

Loads the configuration named variable from the current configuration. This is loaded from the configuration file, environment, or whatever according to the default set in `session-configuration`. Returns `Nil` if no such configuration is defined for the given `$logical-name`.

The boolean flags are used to select which methods will be consulted for determining the variable value.

  * from-instance When True, the local instance variable will be checked.

  * from-env When True, the process environment variables will be searched for the value.

  * from-config When True, the shared configuration file will be consulted for the value.

The value will be pulled in the order listed above, with the first value found being the one chosen.

