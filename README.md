# NAME

AnyEvent::Mattermost - AnyEvent module for interacting with the Mattermost Web Service API

# SYNOPSIS

    use AnyEvent;
    use AnyEvent::Mattermost;

    my $host = "https://mattermost.example.com/";
    my $user = "janedoe";
    my $pass = "foobar123";

    my $cond = AnyEvent->condvar;
    my $mconn = AnyEvent::Mattermost->new($host, $user, $pass);

    $mconn->on('message' => sub {
        my ($self, $message) = @_;
        print "> $message->{text}\n";
    });

    $mconn->start;
    AnyEvent->condvar->recv;

# DESCRIPTION

This module provides an [AnyEvent](https://metacpan.org/pod/AnyEvent) based interface to Mattermost chat servers
using the Web Service API.

It is very heavily inspired by [AnyEvent::SlackRTM](https://metacpan.org/pod/AnyEvent::SlackRTM) and I owe a debt of
gratitude to Andrew Hanenkamp for his work on that module.

This library is still very basic and currently attempts to implement little
beyond authentication and simple message receiving and sending. Feature parity
with SlackRTM support is a definite goal, and then beyond that it would be nice
to support all the stable Mattermost API features. Baby steps.

# METHODS

## new

## start

## ping

## send

# INTERNAL METHODS

The following methods are not intended to be used by code outside this module,
and their signatures (even their very existence) are not guaranteed to remain
stable between versions. However, if you're the adventurous type ...

## started

# AUTHOR

Jon Sime <jonsime@gmail.com>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2016 by Jon Sime.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
