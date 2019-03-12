use v6;

use Test;
use AWS::Credentials;

use lib 't/lib';
use Test::AWS::Session;

plan 2;

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

done-testing;

# vim: ts=4 sts=4 sw=4
