use strict;
use warnings;
package AnyEvent::Mattermost;

# ABSTRACT: AnyEvent module for interacting with Mattermost websockets API.

=pod

=encoding UTF-8

=head1 NAME

AnyEvent::Mattermost - AnyEvent module for interacting with the Mattermost Web Service API

=cut

use AnyEvent;
use AnyEvent::WebSocket::Client 0.37;
use Carp;
use Data::Dumper;
use Furl;
use JSON;
use Time::HiRes qw( time );
use Try::Tiny;

=head1 SYNOPSIS

    use AnyEvent;
    use AnyEvent::Mattermost;

    my $host = "https://mattermost.example.com/";
    my $team = "awesome-chat";
    my $user = "janedoe@example.com";
    my $pass = "foobar123";

    my $cond = AnyEvent->condvar;
    my $mconn = AnyEvent::Mattermost->new($host, $team, $user, $pass);

    $mconn->on('message' => sub {
        my ($self, $message) = @_;
        print "> $message->{text}\n";
    });

    $mconn->start;
    AnyEvent->condvar->recv;

=head1 DESCRIPTION

This module provides an L<AnyEvent> based interface to Mattermost chat servers
using the Web Service API.

It is very heavily inspired by L<AnyEvent::SlackRTM> and I owe a debt of
gratitude to Andrew Hanenkamp for his work on that module.

This library is still very basic and currently attempts to implement little
beyond authentication and simple message receiving and sending. Feature parity
with SlackRTM support is a definite goal, and then beyond that it would be nice
to support all the stable Mattermost API features. Baby steps.

=head1 METHODS

=cut

=head2 new

=cut

sub new {
    my ($class, $host, $team, $user, $pass) = @_;

    croak "must provide a Mattermost server address"
        unless defined $host && length($host) > 0;
    croak "must provide a Mattermost team name"
        unless defined $team && length($team) > 0;
    croak "must provide a login email and password"
        unless defined $user && defined $pass && length($user) > 0 && length($pass) > 0;

    $host = "https://$host" unless $host =~ m{^https?://}i;
    $host .= '/' unless substr($host, -1, 1) eq '/';

    return bless {
        furl     => Furl->new( agent => "AnyEvent::Mattermost" ),
        host     => $host,
        team     => $team,
        user     => $user,
        pass     => $pass,
        registry => {},
        channels => {},
    }, $class;
}

=head2 start

=cut

sub start {
    my ($self) = @_;

    my $data = $self->_post('api/v3/users/login', {
        name     => $self->{'team'},
        login_id => $self->{'user'},
        password => $self->{'pass'},
    });

    croak "could not log in" unless exists $self->{'token'};

    my $userdata = $self->_get('api/v3/users/initial_load');

    croak "did not receive valid initial_load user data"
        unless exists $userdata->{'user'}
            && ref($userdata->{'user'}) eq 'HASH'
            && exists $userdata->{'user'}{'id'};

    croak "did not receive valid initial_load teams data"
        unless exists $userdata->{'teams'}
            && ref($userdata->{'teams'}) eq 'ARRAY'
            && grep { $_->{'name'} eq $self->{'team'} } @{$userdata->{'teams'}};

    $self->{'userdata'} = $userdata->{'user'};
    $self->{'teamdata'} = (grep { $_->{'name'} eq $self->{'team'} } @{$userdata->{'teams'}})[0];

    my $wss_url = $self->{'host'} . 'api/v3/users/websocket';
    $wss_url =~ s{^http(s)?}{ws$1}i;

    $self->{'client'} = AnyEvent::WebSocket::Client->new(
        http_headers => $self->_headers
    );

    $self->{'client'}->connect($wss_url)->cb(sub {
        my $client = shift;

        my $conn = try {
            $client->recv;
        }
        catch {
            die $_;
        };

        $self->{'started'}++;
        $self->{'conn'} = $conn;
    });
}

=head2 ping

=cut

sub ping {
    my ($self) = @_;

    $self->{'conn'}->send("ping");
}

=head2 send

=cut

sub send {
    my ($self, $data) = @_;

    croak "cannot send message because connection has not yet started"
        unless $self->started;

    croak "send payload must be a hashref"
        unless defined $data && ref($data) eq 'HASH';
    croak "message must be a string of greater than zero bytes"
        unless exists $data->{'message'} && !ref($data->{'message'}) && length($data->{'message'}) > 0;
    croak "message must have a destination channel"
        unless exists $data->{'channel'} && length($data->{'channel'}) > 0;

    my $team_id = $self->{'teamdata'}{'id'};
    my $user_id = $self->{'userdata'}{'id'};
    my $channel_id = $self->_get_channel_id($data->{'channel'});

    my $create_at = int(time() * 1000);

    my $res = $self->_post('api/v3/teams/' . $team_id . '/channels/' . $channel_id . '/posts/create', {
        user_id         => $user_id,
        channel_id      => $channel_id,
        message         => $data->{'message'},
        create_at       => $create_at+0,
        filenames       => [],
        pending_post_id => $user_id . ':' . $create_at,
    });
}


=head1 INTERNAL METHODS

The following methods are not intended to be used by code outside this module,
and their signatures (even their very existence) are not guaranteed to remain
stable between versions. However, if you're the adventurous type ...

=cut

=head2 started

=cut

sub started {
    my ($self) = @_;

    return $self->{'started'} // 0;
}



sub _get_channel_id {
    my ($self, $channel_name) = @_;

    unless (exists $self->{'channels'}{$channel_name}) {
        my $data = $self->_get('api/v3/teams/' . $self->{'teamdata'}{'id'} . '/channels/');

        croak "no channels returned"
            unless defined $data && ref($data) eq 'HASH'
                && exists $data->{'channels'} && ref($data->{'channels'}) eq 'ARRAY';

        foreach my $channel (@{$data->{'channels'}}) {
            next unless ref($channel) eq 'HASH'
                && exists $channel->{'id'} && exists $channel->{'name'};

            $self->{'channels'}{$channel->{'name'}} = $channel->{'id'};
        }

        # Ensure that we got the channel we were looking for.
        croak "channel $channel_name was not found"
            unless exists $self->{'channels'}{$channel_name};
    }

    return $self->{'channels'}{$channel_name};
}

sub _get {
    my ($self, $path) = @_;

    my $furl = $self->{'furl'};
    my $res = $furl->get($self->{'host'} . $path, $self->_headers);

    my $data = try {
        decode_json($res->content);
    } catch {
        my $status = $res->status;
        my $message = $res->content;
        croak "unable to call $path: $status $message";
    };

    return $data;
}

sub _post {
    my ($self, $path, $postdata) = @_;

    my $furl = $self->{'furl'};

    my $res = try {
        $furl->post($self->{'host'} . $path, $self->_headers, encode_json($postdata));
    } catch {
        croak "unable to post to mattermost api: $_";
    };

    # Check for session token and update if it was present in response.
    if (my $token = $res->header('Token')) {
        $self->{'token'} = $token;
    }

    my $data = try {
        decode_json($res->content);
    } catch {
        my $status = $res->status;
        my $message = $res->content;
        croak "unable to call $path: $status $message";
    };

    return $data;
}

sub _headers {
    my ($self) = @_;

    my $headers = [
        'Content-Type'      => 'application/json',
        'X-Requested-With'  => 'XMLHttpRequest',
    ];

    # initial_load is fine with just the Cookie, other endpoints like channels/
    # require Authorization. We'll just always include both to be sure.
    if (exists $self->{'token'}) {
        push(@{$headers},
            'Cookie'        => 'MMAUTHTOKEN=' . $self->{'token'},
            'Authorization' => 'Bearer ' . $self->{'token'},
        );
    }

    return $headers;
}

=head1 AUTHOR

Jon Sime <jonsime@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2016 by Jon Sime.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

1;
