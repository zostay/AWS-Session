use v6;

use Test;
use AWS::Credentials;

use lib 't/lib';
use Test::AWS::Session;

plan 5;

constant TEST-ROLE-FETCHER = class {
    method retrieve-iam-role-credentials(--> Hash) {
        %(
            role-name   => 'RoleyPoley',
            access-key  => 'AKEYIMDSACCESSKEY',
            secret-key  => 'IMDSSecretKey',
            token       => 'IMDSToken',
            expiry-time => DateTime.now + Duration.new(60*60),
        );
    }
}.new;

constant SAD-TEST-ROLE-FETCHER = class {
    method retrieve-iam-role-credentials(--> Hash) {
        %()
    }
}.new;

# This tests the the credentials with a mocked role fetcher
subtest 'happy-imds-credentials', {
    my $resolver = AWS::Credentials::Provider::InstanceMetadataProvider.new(
        role-fetcher => TEST-ROLE-FETCHER,
    );

    my $session = AWS::Session.new(
        session-configuration => TEST-SESSION-DEFAULTS,
    );

    my $credentials = load-credentials($session, :$resolver);

    isa-ok $credentials, AWS::Credentials::Refreshable;

    is $credentials.access-key, 'AKEYIMDSACCESSKEY';
    is $credentials.secret-key, 'IMDSSecretKey';
    is $credentials.token, 'IMDSToken';
}

# This tests the the credentials with a mocked role fetcher
subtest 'sad-imds-credentials', {
    my $resolver = AWS::Credentials::Provider::InstanceMetadataProvider.new(
        role-fetcher => SAD-TEST-ROLE-FETCHER,
    );

    my $session = AWS::Session.new(
        session-configuration => TEST-SESSION-DEFAULTS,
    );

    my $credentials = load-credentials($session, :$resolver);

    ok !$credentials.defined;
}

# This tests the credential fetcher by mocking some internals
subtest 'happy-imds-fetcher', {
    my Bool $get-iam-role = False;
    my $get-credentials;

    my class AWS::InstanceMetadataFetcher::Test is AWS::InstanceMetadataFetcher {
        method get-iam-role(--> Str:D) { $get-iam-role++; 'steve' }
        method get-credentials($role-name --> Hash) {
            $get-credentials = $role-name;
            %(
                AccessKeyId => 'AKEYFORSTEVE',
                SecretAccessKey => 'SecretForSteve',
                Token => 'TokenForSteve',
                Expiration => ~(DateTime.now + Duration.new(60 * 60))
            )
        }
    }

    my $fetcher = AWS::InstanceMetadataFetcher::Test.new;
    my %credentials = $fetcher.retrieve-iam-role-credentials;

    ok $get-iam-role;
    is $get-credentials, 'steve';

    is %credentials<access-key>, 'AKEYFORSTEVE';
    is %credentials<secret-key>, 'SecretForSteve';
    is %credentials<token>,      'TokenForSteve';
    cmp-ok %credentials<expiry-time>, 'after', DateTime.now + Duration.new(60 * 59);
}

# This tests the credential fetcher by mocking some internals
subtest 'happy-imds-fetcher-from-request', {
    my class AWS::InstanceMetadataFetcher::Test is AWS::InstanceMetadataFetcher {
        use HTTP::Response;
        method get-request(Str :$url, :&retrier is copy --> HTTP::Response) {

            if $url.ends-with('latest/meta-data/iam/security-credentials/') {
                my $r = HTTP::Response.new(200, Content-Length => 4);
                $r.content = 'phil';
                $r;
            }
            elsif $url.ends-with('latest/meta-data/iam/security-credentials/phil') {
                use JSON::Fast;
                my $data = %(
                    AccessKeyId => 'AKEYFORPHIL',
                    SecretAccessKey => 'SecretForPhil',
                    Token => 'TokenForPhil',
                    Expiration => ~(DateTime.now + Duration.new(60 * 60))
                );
                my $json = to-json($data).encode('utf8');
                my $r = HTTP::Response.new(200, Content-Length => $json.bytes);
                $r.content = $json;
                $r;
            }
            else {
                HTTP::Response.new(404);
            }
        }
    }

    my $fetcher = AWS::InstanceMetadataFetcher::Test.new;
    my %credentials = $fetcher.retrieve-iam-role-credentials;

    is %credentials<access-key>, 'AKEYFORPHIL';
    is %credentials<secret-key>, 'SecretForPhil';
    is %credentials<token>,      'TokenForPhil';
    cmp-ok %credentials<expiry-time>, 'after', DateTime.now + Duration.new(60 * 59);
}

# This tests the credential fetcher by mocking some internals
subtest 'imds-fetcher-retriers', {
    use HTTP::Response;

    my $fetcher = AWS::InstanceMetadataFetcher.new;

    my $goodish = HTTP::Response.new(200);
    $goodish.content = '{}';

    my $not-goodish = HTTP::Response.new(200);
    $not-goodish.content = 'NOT GOOD';

    my $badish = HTTP::Response.new(200);
    my $very-badish = HTTP::Response.new(500);

    subtest 'default-retier', {
        my &retrier = $fetcher.default-retrier;
        nok retrier($goodish);
        nok retrier($not-goodish);
        ok retrier($badish);
        ok retrier($very-badish);
    }

    subtest 'needs-retry-for-role-name', {
        my &retrier = $fetcher.needs-retry-for-role-name;
        nok retrier($goodish);
        nok retrier($not-goodish);
        ok retrier($badish);
        ok retrier($very-badish);
    }

    subtest 'needs-retry-for-credentials', {
        my &retrier = $fetcher.needs-retry-for-credentials;
        nok retrier($goodish);
        ok retrier($not-goodish);
        ok retrier($badish);
        ok retrier($very-badish);
    }
}

done-testing;

# vim: ts=4 sts=4 sw=4
