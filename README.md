# AnyEvent::WebSocket::Client [![Build Status](https://secure.travis-ci.org/plicease/AnyEvent-WebSocket-Client.png)](http://travis-ci.org/plicease/AnyEvent-WebSocket-Client)

WebSocket client for AnyEvent

# VERSION

version 0.11\_02

# SYNOPSIS

    use AnyEvent::WebSocket::Client;
    
    my $client = AnyEvent::WebSocket::Client->new;
    
    $client->connect("ws://localhost:1234/service")->cb(sub {
      my $connection = eval { shift->recv };
      if($@) {
        # handle error...
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

# DESCRIPTION

This class provides an interface to interact with a web server that provides
services via the WebSocket protocol in an [AnyEvent](http://search.cpan.org/perldoc?AnyEvent) context.  It uses
[Protocol::WebSocket](http://search.cpan.org/perldoc?Protocol::WebSocket) rather than reinventing the wheel.  You could use 
[AnyEvent](http://search.cpan.org/perldoc?AnyEvent) and [Protocol::WebSocket](http://search.cpan.org/perldoc?Protocol::WebSocket) directly if you wanted finer grain
control, but if that is not necessary then this class may save you some time.

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
defined by the given URL.  The URL may be either an instance of [URI::ws](http://search.cpan.org/perldoc?URI::ws),
[URI::wss](http://search.cpan.org/perldoc?URI::wss), or a string that represents a legal WebSocket URL.

This method will return an [AnyEvent](http://search.cpan.org/perldoc?AnyEvent) condition variable which you can 
attach a callback to.  The value sent through the condition variable will
be either an instance of [AnyEvent::WebSocket::Connection](http://search.cpan.org/perldoc?AnyEvent::WebSocket::Connection) or a croak
message indicating a failure.  The synopsis above shows how to catch
such errors using `eval`.

# CAVEATS

This is pretty simple minded and there are probably WebSocket features
that you might like to use that aren't supported by this distribution.
Patches are encouraged to improve it.

# SEE ALSO

- [AnyEvent::WebSocket::Connection](http://search.cpan.org/perldoc?AnyEvent::WebSocket::Connection)
- [AnyEvent::WebSocket::Message](http://search.cpan.org/perldoc?AnyEvent::WebSocket::Message)
- [AnyEvent](http://search.cpan.org/perldoc?AnyEvent)
- [URI::ws](http://search.cpan.org/perldoc?URI::ws)
- [URI::wss](http://search.cpan.org/perldoc?URI::wss)
- [Protocol::WebSocket](http://search.cpan.org/perldoc?Protocol::WebSocket)
- [RFC 6455 The WebSocket Protocol](http://tools.ietf.org/html/rfc6455)

# AUTHOR

author: Graham Ollis <plicease@cpan.org>

contributors:

Toshio Ito

# COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Graham Ollis.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
