use v6;
unit module Test::AWS::Session;

use AWS::Session;

# For testing, we want to avoid touching any real credentials. This clears any
# input that might tell us to try and read real credentials from the
# environment and such.
#
# We also set AWS_EC2_METADATA_DISABLED to keep us from trying the local
# metadata server during tests.
sub expunge-real-credentials() {
    %*ENV<AWS_EC2_METADATA_DISABLED> = 'true';
    %*ENV<AWS_ACCESS_KEY_ID>:delete;
    %*ENV<AWS_SECRET_ACCESS_KEY>:delete;
    %*ENV<AWS_SECURITY_TOKEN>:delete;
    %*ENV<AWS_SESSION_TOKEN>:delete;
    %*ENV<AWS_CREDENTIAL_EXPIRATION>:delete;
    %*ENV<HOME> = "$*CWD";
}


sub TEST-SESSION-DEFAULTS is export {
    expunge-real-credentials;
    my %configuration := AWS::Session.DEFAULTS;
    %configuration<config-file>.default-value = 't/aws/config';
    %configuration<credentials-file>.default-value = 't/aws/credentials';
    %configuration;
}

sub TEST-SESSION-SAD-DEFAULTS is export {
    expunge-real-credentials;
    my %configuration := AWS::Session.DEFAULTS;
    %configuration<config-file>.default-value = 't/aws.not-here/config';
    %configuration<credentials-file>.default-value = 't/aws.not-here/credentials';
    %configuration;
}

# vim: ts=4 sts=4 sw=4
