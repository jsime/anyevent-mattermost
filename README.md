# NAME

AnyEvent::Mattermost - AnyEvent module for interacting with the Mattermost APIs

# SYNOPSIS

    use AnyEvent;
    use AnyEvent::Mattermost;

    my $host = "https://mattermost.example.com/";
    my $team = "awesome-chat";
    my $user = "janedoe@example.com";
    my $pass = "foobar123";

    my $cond = AnyEvent->condvar;
    my $mconn = AnyEvent::Mattermost->new($host, $team, $user, $pass);

    $mconn->on('posted' => sub {
        my ($self, $message) = @_;
        printf "<%s> %s\n", $message->{data}{sender_name}, $message->{data}{post}";
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

    new( $host, $team, $email, $password )

Creates a new AnyEvent::Mattermost object. No connections are opened and no
callbacks are registered yet.

The `$host` parameter must be the HTTP/HTTPS URL of your Mattermost server. If
you omit the scheme and provide only a hostname, HTTPS will be assumed. Note
that Mattermost servers configured over HTTP will also use unencrypted `ws://`
for the persistent WebSockets connection for receiving incoming messages. You
should use HTTPS unless there is no other choice.

`$team` must be the Mattermost team's short name (the version which appears in
the URLs when connected through the web client).

`$email` must be the email address of the account to be used for logging into
the Mattermost server. The short username is not supported for logins via the
Mattermost APIs, only the email address.

`$password` is hopefully self-explanatory.

## start

    start()

Opens the connection to the Mattermost server, authenticates the previously
provided account credentials and performs an initial data request for user,
team, and channel information.

Any errors encountered will croak() and the connection will be aborted.

## on

    on( $event1 => sub {}, [ $event2 => sub {}, ... ] )

Registers a callback for the named event type. Multiple events may be registered
in a single call to on(), but only one callback may exist for any given event
type. Any subsequent callbacks registered to an existing event handler will
overwrite the previous callback.

Every callback will receive two arguments: the AnyEvent::Mattermost object and
the raw message data received over the Mattermost WebSockets connection. This
message payload will take different forms depending on the type of event which
occurred, but the top-level data structure is always a hash reference with at
least the key `event` (with a value matching that which you used to register
the callback). Most event types include a `data` key, whose value is a hash
reference containing the payload of the event. For channel messages this will
include things like the sender's name, the channel name and type, and of course
the message itself.

For more explanation of event types, hope that the Mattermost project documents
them at some point. For now, [Data::Dumper](https://metacpan.org/pod/Data::Dumper) based callbacks are your best bet.

## ping

    ping()

Pings the Mattermost server over the WebSocket connection to maintain online
status and ensure the connection remains alive. You should not have to call
this method yourself, as start() sets up a ping callback on a timer for you.

## send

    send( \%message )

Posts a message to the Mattermost server. This method is currently fairly
limited and supports only providing a channel name and a message body. There
are formatting, attachment, and other features that are planned to be
supported in future releases.

The `\%message` hash reference should contain at bare minimum two keys:

- channel

    The name of the channel to which the message should be posted.

- message

    The body of the message to be posted. This may include any markup options that
    are supported by Mattermost, which includes a subset of the Markdown language
    among other things.

To announce your presence to the default Mattermost channel (Town Square), you
might call the method like this:

    send({ channel => "town-square", message => "Hey everybody!" })

# INTERNAL METHODS

The following methods are not intended to be used by code outside this module,
and their signatures (even their very existence) are not guaranteed to remain
stable between versions. However, if you're the adventurous type ...

## started

    started()

Returns a boolean status indicating whether the Mattermost WebSockets API
connection has started yet.

# LIMITATIONS

- Only basic message sending and receiving is currently supported.

# CONTRIBUTING

If you would like to contribute to this module, report bugs, or request new
features, please visit the module's official GitHub project:

[https://github.com/jsime/anyevent-mattermost](https://github.com/jsime/anyevent-mattermost)

# AUTHOR

Jon Sime <jonsime@gmail.com>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2016 by Jon Sime.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
