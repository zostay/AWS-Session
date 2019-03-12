use v6;

use Test;
use AWS::Credentials;

use lib 't/lib';
use Test::AWS::Session;

plan 3;

subtest 'env-credentials-security-token', {
    my $session = AWS::Session.new(
        session-configuration => TEST-SESSION-DEFAULTS(),
    );

    %*ENV = %(
        |%*ENV,
        AWS_ACCESS_KEY_ID     => 'AKEYFROMENV',
        AWS_SECRET_ACCESS_KEY => 'SecretFromEnv',
        AWS_SECURITY_TOKEN    => 'TokenFromEnv',
    );

    subtest 'default-profile', {
        my $credentials = load-credentials($session);

        does-ok $credentials, AWS::Credentials;

        is $credentials.access-key, 'AKEYFROMENV';
        is $credentials.secret-key, 'SecretFromEnv';
        is $credentials.token, 'TokenFromEnv';
    }

    $session.profile = 'fun';

    subtest 'fun-profile', {
        my $credentials = load-credentials($session);

        does-ok $credentials, AWS::Credentials;

        is $credentials.access-key, 'AKEYFROMENV';
        is $credentials.secret-key, 'SecretFromEnv';
        is $credentials.token, 'TokenFromEnv';
    }
}

subtest 'env-credentials-session-token', {
    my $session = AWS::Session.new(
        session-configuration => TEST-SESSION-DEFAULTS(),
    );

    %*ENV = %(
        |%*ENV,
        AWS_ACCESS_KEY_ID     => 'AKEYFROMENV',
        AWS_SECRET_ACCESS_KEY => 'SecretFromEnv',
        AWS_SESSION_TOKEN     => 'TokenFromEnv',
    );

    subtest 'default-profile', {
        my $credentials = load-credentials($session);

        does-ok $credentials, AWS::Credentials;

        is $credentials.access-key, 'AKEYFROMENV';
        is $credentials.secret-key, 'SecretFromEnv';
        is $credentials.token, 'TokenFromEnv';
    }

    $session.profile = 'fun';

    subtest 'fun-profile', {
        my $credentials = load-credentials($session);

        does-ok $credentials, AWS::Credentials;

        is $credentials.access-key, 'AKEYFROMENV';
        is $credentials.secret-key, 'SecretFromEnv';
        is $credentials.token, 'TokenFromEnv';
    }
}

subtest 'env-credentials-refresh', {
    my $session = AWS::Session.new(
        session-configuration => TEST-SESSION-DEFAULTS(),
    );

    my $expiration = DateTime.now + Duration.new(60*20);

    %*ENV = %(
        |%*ENV,
        AWS_ACCESS_KEY_ID         => 'AKEYFROMENV',
        AWS_SECRET_ACCESS_KEY     => 'SecretFromEnv',
        AWS_SECURITY_TOKEN        => 'TokenFromEnv',
        AWS_CREDENTIAL_EXPIRATION => ~$expiration,
    );

    my $credentials = load-credentials($session);

    does-ok $credentials, AWS::Credentials;
    isa-ok $credentials, AWS::Credentials::Refreshable;

    my $new-expiration = DateTime.now + Duration.new(60*35);

    %*ENV = %(
        |%*ENV,
        AWS_ACCESS_KEY_ID         => 'AKEYFROMENVREFRESHED',
        AWS_SECRET_ACCESS_KEY     => 'SecretFromEnvRefreshed',
        AWS_SECURITY_TOKEN        => 'TokenFromEnvRefreshed',
        AWS_CREDENTIAL_EXPIRATION => ~$new-expiration,
    );

    is $credentials.access-key, 'AKEYFROMENV';
    is $credentials.secret-key, 'SecretFromEnv';
    is $credentials.token, 'TokenFromEnv';
    is $credentials.expiry-time, $expiration;

    $credentials.advisory-refresh-timeout .= new(60*30);

    is $credentials.access-key, 'AKEYFROMENVREFRESHED';
    is $credentials.secret-key, 'SecretFromEnvRefreshed';
    is $credentials.token, 'TokenFromEnvRefreshed';
    is $credentials.expiry-time, $new-expiration;
}

done-testing;

# vim: ts=4 sts=4 sw=4
