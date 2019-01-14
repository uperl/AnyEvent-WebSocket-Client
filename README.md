# AnyEvent::WebSocket::Client [![Build Status](https://secure.travis-ci.org/plicease/AnyEvent-WebSocket-Client.png)](http://travis-ci.org/plicease/AnyEvent-WebSocket-Client)

WebSocket client for AnyEvent

# SYNOPSIS

    use AnyEvent::WebSocket::Client 0.12;
    
    my $client = AnyEvent::WebSocket::Client->new;
    
    $client->connect("ws://localhost:1234/service")->cb(sub {
    
      # make $connection an our variable rather than
      # my so that it will stick around.  Once the
      # connection falls out of scope any callbacks
      # tied to it will be destroyed.
      our $connection = eval { shift->recv };
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

    ## uncomment to enter the event loop before exiting.
    ## Note that calling recv on a condition variable before
    ## it has been triggered does not work on all event loops
    #AnyEvent->condvar->recv;

# DESCRIPTION

This class provides an interface to interact with a web server that provides
services via the WebSocket protocol in an [AnyEvent](https://metacpan.org/pod/AnyEvent) context.  It uses
[Protocol::WebSocket](https://metacpan.org/pod/Protocol::WebSocket) rather than reinventing the wheel.  You could use 
[AnyEvent](https://metacpan.org/pod/AnyEvent) and [Protocol::WebSocket](https://metacpan.org/pod/Protocol::WebSocket) directly if you wanted finer grain
control, but if that is not necessary then this class may save you some time.

The recommended API was added to the [AnyEvent::WebSocket::Connection](https://metacpan.org/pod/AnyEvent::WebSocket::Connection)
class with version 0.12, so it is recommended that you include that version
when using this module.  The older version of the API has since been
deprecated and removed.

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

## protocol\_version

The protocol version.  See [Protocol::WebSocket](https://metacpan.org/pod/Protocol::WebSocket) for the list of supported
WebSocket protocol versions.

## subprotocol

List of subprotocols to request from the server.  This class will throw an
exception if none of the protocols are supported by the server.

## http\_headers

Extra headers to include in the initial request.  May be either specified
as a hash reference, or an array reference.  For example:

    AnyEvent::WebSocket::Client->new(
      http_headers => {
        'X-Foo' => 'bar',
        'X-Baz' => [ 'abc', 'def' ],
      },
    );
    
    AnyEvent::WebSocket::Client->new(
      http_headers => [
        'X-Foo' => 'bar',
        'X-Baz' => 'abc',
        'X-Baz' => 'def',
      ],
    );

Will generate:

    X-Foo: bar
    X-Baz: abc
    X-Baz: def

Although, the order cannot be guaranteed when using the hash style.

## max\_payload\_size

The maximum payload size for received frames.  Currently defaults to whatever
[Protocol::WebSocket](https://metacpan.org/pod/Protocol::WebSocket) defaults to.

## max\_fragments

The maximum number of fragments for received frames.  Currently defaults to whatever
[Protocol::WebSocket](https://metacpan.org/pod/Protocol::WebSocket) defaults to.

## env\_proxy

If you set true to this boolean attribute, it loads proxy settings
from environment variables. If it finds valid proxy settings,
`connect` method will use that proxy.

Default: false.

For `ws` WebSocket end-points, first it reads `ws_proxy` (or
`WS_PROXY`) environment variable. If it is not set or empty string,
then it reads `http_proxy` (or `HTTP_PROXY`). For `wss` WebSocket
end-points, it reads `wss_proxy` (`WSS_PROXY`) and `https_proxy`
(`HTTPS_PROXY`) environment variables.

# METHODS

## connect

    my $cv = $client->connect($uri)

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
[AnyEvent::FAQ#My-program-exits-before-doing-anything-whats-going-on](https://metacpan.org/pod/AnyEvent::FAQ#My-program-exits-before-doing-anything-whats-going-on).

It is probably also a good idea to review the [AnyEvent](https://metacpan.org/pod/AnyEvent) documentation
if you are new to [AnyEvent](https://metacpan.org/pod/AnyEvent) or event-based programming.

## My callbacks aren't being called!

Make sure that the connection object is still in scope.  This often happens
if you use a `my $connection` variable and don't save it somewhere.  For
example:

    $client->connect("ws://foo/service")->cb(sub {
    
      my $connection = eval { shift->recv };
      
      if($@)
      {
        warn $@;
        return;
      }
      
      ...
    });

Unless `$connection` is saved somewhere it will get deallocated along with
any associated message callbacks will also get deallocated once the connect
callback is executed.  One way to make sure that the connection doesn't
get deallocated is to make it a `our` variable (as in the synopsis above)
instead.

# CAVEATS

This is pretty simple minded and there are probably WebSocket features
that you might like to use that aren't supported by this distribution.
Patches are encouraged to improve it.

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

Author: Graham Ollis <plicease@cpan.org>

Contributors:

Toshio Ito (debug-ito, TOSHIOITO)

José Joaquín Atria (JJATRIA)

Kivanc Yazan (KYZN)

Yanick Champoux (YANICK)

Fayland Lam (FAYLAND)

Daniel Kamil Kozar (xavery)

Michael Shipper (akalinux)

# COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Graham Ollis.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
