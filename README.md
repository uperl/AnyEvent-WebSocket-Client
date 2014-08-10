# AnyEvent::WebSocket::Client [![Build Status](https://secure.travis-ci.org/plicease/AnyEvent-WebSocket-Client.png)](http://travis-ci.org/plicease/AnyEvent-WebSocket-Client)

WebSocket client for AnyEvent

# SYNOPSIS

    use AnyEvent::WebSocket::Client 0.12;
    
    my $client = AnyEvent::WebSocket::Client->new;
    
    $client->connect("ws://localhost:1234/service")->cb(sub {
      my $connection = eval { shift->recv };
      if($@) {
        # handle error...
        warn $@;
        return;
      }
      
      # send a message through the websocket...
      $connection->send('a message');
      
      # recieve message from the websocket...
      $connection->on(each_message => sub {
        # $connection is the same connection object
        # $message isa AnyEvent::WebSocket::Message
        my($connection, $message) = @_;
        ...
      });
      
      # handle a closed connection...
      $connection->on(finish => sub {
        # $connection is the same connection object
        my($connection) = @_;
        ...
      });

      # close the connection (either inside or
      # outside another callback)
      $connection->close;
    
    });
    
    ## uncomment this for simple scripts that
    ## do not otherwise enter the event loop:
    #EV::loop();

# DESCRIPTION

This class provides an interface to interact with a web server that provides
services via the WebSocket protocol in an [AnyEvent](https://metacpan.org/pod/AnyEvent) context.  It uses
[Protocol::WebSocket](https://metacpan.org/pod/Protocol::WebSocket) rather than reinventing the wheel.  You could use 
[AnyEvent](https://metacpan.org/pod/AnyEvent) and [Protocol::WebSocket](https://metacpan.org/pod/Protocol::WebSocket) directly if you wanted finer grain
control, but if that is not necessary then this class may save you some time.

The recommended API was added to the [AnyEvent::WebSocket::Connection](https://metacpan.org/pod/AnyEvent::WebSocket::Connection)
class with version 0.12, so it is recommended that you include that version
when using this module.  The older API will continue to work for now with
deprecation warnings.

# ATTRIBUTES

## timeout

Timeout for the initial connection to the web server.  The default
is 30.

## ssl\_no\_verify

If set to true, then secure WebSockets (those that use SSL/TLS) will
not be verified.  The default is false.

## ssl\_ca\_file

Provide your own CA certificates file instead of using the system default for
SSL/TLS verification.

# METHODS

## $client->connect($uri)

Open a connection to the web server and open a WebSocket to the resource
defined by the given URL.  The URL may be either an instance of [URI::ws](https://metacpan.org/pod/URI::ws),
[URI::wss](https://metacpan.org/pod/URI::wss), or a string that represents a legal WebSocket URL.

This method will return an [AnyEvent](https://metacpan.org/pod/AnyEvent) condition variable which you can 
attach a callback to.  The value sent through the condition variable will
be either an instance of [AnyEvent::WebSocket::Connection](https://metacpan.org/pod/AnyEvent::WebSocket::Connection) or a croak
message indicating a failure.  The synopsis above shows how to catch
such errors using `eval`.

# FAQ

## My program exits before doing anything, what is up with that?

See this FAQ from [AnyEvent](https://metacpan.org/pod/AnyEvent): 
[AnyEvent#My-program-exits-before-doing-anything-whats-going-on](https://metacpan.org/pod/AnyEvent#My-program-exits-before-doing-anything-whats-going-on).

It is probably also a good idea to review the [AnyEvent](https://metacpan.org/pod/AnyEvent) documentation
if you are new to [AnyEvent](https://metacpan.org/pod/AnyEvent) or event-based programming.

# CAVEATS

This is pretty simple minded and there are probably WebSocket features
that you might like to use that aren't supported by this distribution.
Patches are encouraged to improve it.

If you see warnings like this:

    Class::MOP::load_class is deprecated at .../Class/MOP.pm line 71.
    Class::MOP::load_class("Crypt::Random::Source::Weak::devurandom") called at .../Crypt/Random/Source/Factory.pm line 137
    ...

The problem is in the optional [Crypt::Random::Source](https://metacpan.org/pod/Crypt::Random::Source) module, and has
been reported here:

[https://rt.cpan.org/Ticket/Display.html?id=93163&results=822cf3902026ad4a64ae94b0175207d6](https://rt.cpan.org/Ticket/Display.html?id=93163&results=822cf3902026ad4a64ae94b0175207d6)

You can use the patch provided there to silence the warnings.

# SEE ALSO

- [AnyEvent::WebSocket::Connection](https://metacpan.org/pod/AnyEvent::WebSocket::Connection)
- [AnyEvent::WebSocket::Message](https://metacpan.org/pod/AnyEvent::WebSocket::Message)
- [AnyEvent::WebSocket::Server](https://metacpan.org/pod/AnyEvent::WebSocket::Server)
- [AnyEvent](https://metacpan.org/pod/AnyEvent)
- [URI::ws](https://metacpan.org/pod/URI::ws)
- [URI::wss](https://metacpan.org/pod/URI::wss)
- [Protocol::WebSocket](https://metacpan.org/pod/Protocol::WebSocket)
- [Net::WebSocket::Server](https://metacpan.org/pod/Net::WebSocket::Server)
- [Net::Async::WebSocket](https://metacpan.org/pod/Net::Async::WebSocket)
- [RFC 6455 The WebSocket Protocol](http://tools.ietf.org/html/rfc6455)

# AUTHOR

author: Graham Ollis <plicease@cpan.org>

contributors:

Toshio Ito

# COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Graham Ollis.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
