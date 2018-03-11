use v6;

use Test;
use AWS::Session;

plan 16;

constant Default = AWS::Session::Default;
constant &IO-and-tilde = &AWS::Session::IO-and-tilde;
constant %test-session-variables = %(
    profile => Default.new(:env-var<AWS_DEFAULT_PROFILE AWS_PROFILE>, :default-value<default>),
    region => Default.new(:config-file<region>, :env-var<AWS_DEFAULT_REGION>),
    data-path => Default.new(:config-file<data-path>, :env-var<AWS_DATA_PATH>, :converter(&IO-and-tilde)),
    config-file => Default.new(:env-var<AWS_CONFIG_FILE>, :default-value<t/aws/config>, :converter(&IO-and-tilde)),
    ca-bundle => Default.new(:config-file<ca_bundle>, :env-var<AWS_CA_BUNDLE>, :converter(&IO-and-tilde)),
    api-versions => Default.new(:config-file<api-version>, :default-value(%)),

    credentials-file => Default.new(
        :env-var<AWS_SHARED_CREDENTIALS_FILE>,
        :default-value<t/aws/credentials>,
        :converter(&IO-and-tilde),
    ),

    metadata-service-timeout => Default.new(
        :config-file<metadata_service_timeout>,
        :env-var<AWS_METADATA_SERVICE_TIMEOUT>,
        :default-value(1),
        :converter({.Int}),
    ),

    metadata-service-num-attempts => Default.new(
        :config-file<metadata_service_num_attempts>,
        :env-var<AWS_METADATA_SERVICE_NUM_ATTEMPTS>,
        :default-value(1),
        :converter({.Int}),
    ),
);

my $session = AWS::Session.new(
    session-configuration => %test-session-variables,
    data-path => 't/aws/my-data'.IO,
);

isa-ok $session, AWS::Session;

is $session.profile, 'default';
is $session.region, 'us-west-1';
is $session.data-path, Nil;
is $session.config-file, 't/aws/config';
is $session.ca-bundle, Nil;
is $session.api-versions, {};
is $session.credentials-file, 't/aws/credentials';
is $session.metadata-service-timeout, 1;
is $session.metadata-service-num-attempts, 1;

is $session.get-configuration.<default><region>, 'us-west-1';
is $session.get-current-configuration.<output>, 'json';
is $session.get-profile-configuration('fun').<region>, 'us-east-2';

is $session.get-credentials.<default><aws_access_key_id>, 'AKEYDEFAULTDEFAULTDE';
is $session.get-current-credentials.<aws_secret_access_key>, 'SecretSecretSecretSecretSecretSecretSecr';
is $session.get-profile-credentials('fun').<aws_access_key_id>, 'AKEYFUNFUNFUNFUNFUNF';

done-testing;
