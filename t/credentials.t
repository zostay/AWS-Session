use v6;

use Test;
use AWS::Credentials;

use lib 't/lib';
use Test::AWS::Session;

plan 2;

subtest 'happy-credentials', {
    my $session = AWS::Session.new(
        session-configuration => TEST-SESSION-DEFAULTS(),
    );

    subtest 'default-profile', {
        my $credentials = load-credentials($session);

        isa-ok $credentials, AWS::Credentials;

        is $credentials.access-key, 'AKEYDEFAULTDEFAULTDE';
        is $credentials.secret-key, 'SecretSecretSecretSecretSecretSecretSecr';
    }

    $session.profile = 'fun';
    #dd $session.profile;

    subtest 'fun-profile', {
        my $credentials = load-credentials($session);

        isa-ok $credentials, AWS::Credentials;

        is $credentials.access-key, 'AKEYFUNFUNFUNFUNFUNF';
        is $credentials.secret-key, 'AlsoSecretSecretSecretSecretSecretSecret';
    }
}

subtest 'sad-credentials', {
    my $session = AWS::Session.new(
        session-configuration => TEST-SESSION-SAD-DEFAULTS(),
    );

    subtest 'default-profile', {
        my $credentials = load-credentials($session);

        ok !$credentials.defined;
    }

    $session.profile = 'fun';
    #dd $session.profile;

    subtest 'fun-profile', {
        my $credentials = load-credentials($session);

        ok !$credentials.defined;
    }
}

done-testing;
