use v6;

use AWS::Session;

=begin pod

=head1 NAME

AWS::Credentials - Tools for loading AWS credentials

=head1 SYNOPSIS

    use AWS::Credentials;

    my $credentials = load-credentials();

    my $access-key  = $credentials.access-key;
    my $secret-key  = $credentials.secret-key;
    my $token       = $credentials.token;

    # Or if you insist:
    my $hardcoded = AWS::Credentials.new(
        access-key => 'AKISUCHABADIDEATOHAV',
        secret-key => 'PJaLYouReallyOughtNotToDoThisOrPainComes',
    );

=head1 DESCRIPTION

Hardcoded credentials are a terrible idea when using AWS. This module helps to
make it easy to pull credentials from the current environment.

It will even let you set them explicitly too, if you insist.

The recommended way to construct this object is to use the C<load-credentials()>
subroutine. This takes or automatically constructs an L<AWS::Session> object
that represents the state of configuration in the local environment and uses
that and other aspects of the local environment to locate the credentials that
should be used by this service.

    # Use a newly constructed session
    {
        my $credentials = load-credentials();
    }

    # OR if you already have a session object
    {
        use AWS::Session;
        my $session = AWS::Session.new(:profile<production>);
        my $credentials = load-credentials($session);
    }

B<NOTE:> As of this writing, only a few of the credential providers have been
written, so certain common ways of retrieving credentials that are available to
botocore and similar tools may not be available yet to users of this module.
Patches welcome.

If you really just need a L<AWS::Credentials> object and you don't have time to
trouble yourself with complexities like environment variables or configuration
files:

    my $credentials = AWS::Credentials.new(
        access-key => 'AKISUCHABADIDEATOHAV',
        secret-key => 'PJaLYouReallyOughtNotToDoThisOrPainComes',
    );

I humbly suggest that might never be a good reason for doing this.

=head1 ATTRIBUTES

The main credentials object will store credentials for use with any library that
can make use of them.

=head2 access-key

=head2 secret-key

=head2 token

=head1 EXPORTED SUBROUTINES

=head2 sub load-credentials

    sub load-credentials(
        AWS::Session $session?,
        AWS::Credentials::Provider :$resolver?,
    ) returns AWS::Credentials

This subroutine is the entrypoint to gaining credentials. For most uses, calling this method with no arguments should be safe to do. If you have a L<AWS::Session> object already, you will probably want to pass it through to avoid construct a new session with every call.

If you need to customize credential resolution in some way, you can provide your own resolver to the process.

For example, let's say you want to have some hardcoded credentials that used as the fallback credentials in your code. You could do something like this:

    my $resolver = AWS::Credentials::Provider::Resolver.DEFAULT;
    $resolver.providers.push: class :: does AWS::Credentials::Provider {
        method load($s) returns AWS::Credentials {
            self.static-credentials.new(
                access-key => 'AKISUCHABADIDEATOHAV',
                secret-key => 'PJaLYouReallyOughtNotToDoThisOrPainComes',
            );
        }
    }

    my $credentials = load-credentials(:$resolver);

=end pod

class X::AWS::Credentials is Exception {
}

class X::AWS::Credentials::RetriesExceeded is X::AWS::Credentials {
    method message() { "too many retries attempted while retrieving credentials" }
}

class X::AWS::Credentials::Partial is X::AWS::Credentials {
    has $.provider;
    has Str $.credential-variable;

    method message() {
        "partial credentials found in $!provider.name(), missing: $!credential-variable"
    }
}


role AWS::Credentials:ver<0.5>:auth<github:zostay> {
    has Str $.access-key;
    has Str $.secret-key;
    has Str $.token;
}

class AWS::Credentials::Refreshable does AWS::Credentials {
    # Default number of seconds ahead of expiration where we want to start
    # trying to refresh by default, but we are not willing to block yet.
    has Duration $.advisory-refresh-timeout is rw .= new(60 * 15);

    # Default number of seconds ahead of expiration where we want to start
    # trying to force refresh and are willing to block to make sure it happens.
    has Duration $.mandatory-refresh-timeout is rw .= new(60 * 10);

    has DateTime $.expiry-time;

    has &.refresh-using is required;

    method seconds-remaining(::?CLASS:D:) returns Duration {
        $!expiry-time - DateTime.now
    }

    method refresh-needed(::?CLASS:D:
        $refresh-in = $.mandatory-refresh-timeout,
    ) returns Bool {

        # No expiry time? We will not refresh.
        return False without $!expiry-time;

        # We are not within the expiration time yet
        return False if self.seconds-remaining > $refresh-in;

        # We are within the expiration time
        return True;
    }

    method refresh(::?CLASS:D: :$is-mandatory = False) {
        return unless self.refresh-needed($!advisory-refresh-timeout);

        my %metadata;
        try {
            %metadata = &.refresh-using.();

            CATCH {
                default {
                    my $mandatory = $is-mandatory ?? 'mandatory' !! 'advisory';

                    warn "Refreshing temporary credentials failed during $mandatory refresh period.";

                    .rethrow if $is-mandatory;
                    return;
                }
            }
        }

        $!access-key  = %metadata<access-key>;
        $!secret-key  = %metadata<secret-key>;
        $!token       = %metadata<token>;
        $!expiry-time = %metadata<expiry-time>;

        if $.refresh-needed {
            die X::AWS::Credentials::StillExpired.new;
        }
    }

    method access-key(::?CLASS:D:)  { self.refresh; $!access-key }
    method secret-key(::?CLASS:D:)  { self.refresh; $!secret-key }
    method token(::?CLASS:D:)       { self.refresh; $!token }
    method expiry-time(::?CLASS:D:) { self.refresh; $!expiry-time }
}

role AWS::Credentials::Provider {
    method static-credentials() { AWS::Credentials }
    method refreshable-credentials() { AWS::Credentials::Refreshable }

    method load(AWS::Session $session) returns AWS::Credentials { ... }
}

class AWS::Credentials::Provider::FromEnv does AWS::Credentials::Provider {
    has Str @.access-key = 'AWS_ACCESS_KEY_ID';
    has Str @.secret-key = 'AWS_SECRET_ACCESS_KEY';
    has Str @.token = 'AWS_SECURITY_TOKEN', 'AWS_SESSION_TOKEN';
    has Str @.expiry-time = 'AWS_CREDENTIAL_EXPIRATION';

    method env-map() returns Hash:D {
        %(:@!access-key, :@!secret-key, :@!token, :@!expiry-time)
    }

    multi method load-env('expiry-time', @names) returns DateTime {
        my $expiry-time-str = self.load-env(*, @names);

        return Nil unless $expiry-time-str;

        DateTime.new($expiry-time-str);
    }

    multi method load-env($, @names) returns Str {
        %*ENV{ @names }.first(*.defined)
    }

    method !create-credentials-fetcher($self:) {
        -> {
            % = $.env-map.map({
                my $v = $self.load-env(.key, .value);
                die X::AWS::Credentials::Partial.new(
                    provider            => self.WHAT,
                    credential-variable => .key,
                ) without $v;
                .key => $v;
            })
        }
    }

    method load(AWS::Session $session) returns AWS::Credentials {
        my Str $access-key = self.load-env('access-key', @!access-key);
        return without $access-key;

        my Str $secret-key = self.load-env('secret-key', @!secret-key);
        my Str $token      = self.load-env('token', @!token);

        with self.load-env('expiry-time', @!expiry-time) -> $expiry-time {
            self.refreshable-credentials.new(
                :$expiry-time, :$access-key, :$secret-key, :$token,
                refresh-using => self!create-credentials-fetcher,
            );
        }
        else {
            self.static-credentials.new(:$access-key, :$secret-key, :$token);
        }
    }
}

class AWS::Credentials::Provider::SharedCredentials does AWS::Credentials::Provider {
    has @.access-key = 'aws_access_key_id';
    has @.secret-key = 'aws_secret_access_key';
    has @.token      = 'aws_security_token', 'aws_session_token';

    enum ConfigFileKey <LoadFromCredentials LoadFromConfig>;

    has IO::Path $.credentials-filename;
    has Str $.profile;
    has ConfigFileKey $.configuration-file-key = LoadFromCredentials;

    method load-cred(%cred, @names) returns Str { %cred{ @names }.first(*.defined) }

    method load(AWS::Session $session) returns AWS::Credentials {
        my %cred-config;
        with $!credentials-filename {
            %cred-config = $session.get-credentials($!credentials-filename);
        }
        elsif $!configuration-file-key === LoadFromConfig {
            %cred-config = $session.get-configuration;
        }
        else {
            %cred-config = $session.get-credentials;
        }

        my $cred-profile = $!profile // $session.profile;

        return Nil without %cred-config{ $cred-profile };
        return Nil without any(%cred-config{ $cred-profile }{ @.access-key });

        my %cred = %cred-config{ $cred-profile };
        self.static-credentials.new(
            access-key => self.load-cred(%cred, @!access-key),
            secret-key => self.load-cred(%cred, @!secret-key),
            token      => self.load-cred(%cred, @!token),
        );
    }
}

# TODO AWS::Credentials::Provider::AssumeRoleProvider
#
# This has not been implemented because it requires some sort of AWS API client
# capable of calling sts:AssumeRole. Someone wanting to add this for themselves
# or to send me a PR could either create a one-off API handler for that or could
# look into building a larger implementation of the STS API.
#
# TODO AWS::Credentials::Provider::ContainerProvider
# TODO AWS::Credentials::Provider::InstanceMetadataProvider
#
# Something like these needs to exist too, so that it's easy to pull the AWS
# credentials from the instance using the default instance role or the container
# role. This will at least require an HTTP client and a JSON parser to pull and
# parse the metadata services.

class AWS::Credentials::Provider::Resolver does AWS::Credentials::Provider {
    has AWS::Credentials::Provider @.providers;

    method load(AWS::Session $session) returns AWS::Credentials {
        @!providers.map({ .load($session) }).first({ .defined });
    }

    method DEFAULT {
        AWS::Credentials::Provider::Resolver.new(
            providers => (
                AWS::Credentials::Provider::FromEnv.new,
                AWS::Credentials::Provider::SharedCredentials.new,
                AWS::Credentials::Provider::SharedCredentials.new(
                    :configuration-file-key(AWS::Credentials::Provider::SharedCredentials::LoadFromConfig),
                ),
            ),
        );
    }
}


sub load-credentials(
    AWS::Session $session = AWS::Session.new,
    AWS::Credentials::Provider :$resolver = AWS::Credentials::Provider::Resolver.DEFAULT,
) returns AWS::Credentials is export {
    $resolver.load($session);
}

our constant &AWS::Credentials::load-credentials = &load-credentials;

# vim: sts=4 ts=4 sw=4
