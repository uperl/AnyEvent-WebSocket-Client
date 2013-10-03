package AnyEvent::WebSocket::Client;

use strict;
use warnings;
use v5.10;
use Moo;
use warnings NONFATAL => 'all';
use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::Socket qw( tcp_connect );
use Protocol::WebSocket::Handshake::Client;
use AnyEvent::WebSocket::Connection;
use PerlX::Maybe qw( maybe provided );

# ABSTRACT: WebSocket client for AnyEvent
# VERSION

=head1 SYNOPSIS

 use AnyEvent::WebSocket::Client;
 
 my $client = AnyEvent::WebSocket::Client->new;
 
 $client->connect("ws://localhost:1234")->cb(sub {
   my $connection = eval { shift->recv };
   if($@) {
     # handle error...
   }
   
   # send a message through the websocket...
   $connection->send('a message');
   
   # recieve message from the websocket...
   $connection->on_each_message(sub {
     my $message = shift;
     ...
   });
   
   # handle a closed connection...
   $connection->on_finish(sub {
     ...
   });

   # close the connection (either inside or
   # outside another callback)
   use AnyEvent::WebSocket::Client 0.10; # requires 0.10
   $connection->close;
 
 });

=head1 DESCRIPTION

This class provides an interface to interact with a web server that provides
services via the WebSocket protocol in an L<AnyEvent> context.  It uses
L<Protocol::WebSocket> rather than reinventing the wheel.  You could use 
L<AnyEvent> and L<Protocol::WebSocket> directly if you wanted finer grain
control, but if that is not necessary then this class may save you some time.

=head1 ATTRIBUTES

=head2 timeout

Timeout for the initial connection to the web server.  The default
is 30.

=cut

has timeout => (
  is      => 'ro',
  default => sub { 30 },
);

=head2 ssl_no_verify

If set to true, then secure WebSockets (those that use SSL/TLS) will
not be verified.  The default is false.

=cut

has ssl_no_verify => (
  is => 'ro',
);

=head2 ssl_ca_file

Provide your own CA certificates file instead of using the system default for
SSL/TLS verification.

=cut

has ssl_ca_file => (
  is => 'ro',
);

=head1 METHODS

=head2 $client-E<gt>connect($uri)

Open a connection to the web server and open a WebSocket to the resource
defined by the given URL.  The URL may be either an instance of L<URI::ws>,
L<URI::wss>, or a string that represents a legal WebSocket URL.

This method will return an L<AnyEvent> condition variable which you can 
attach a callback to.  The value sent through the condition variable will
be either an instance of L<AnyEvent::WebSocket::Connection> or a croak
message indicating a failure.  The synopsis above shows how to catch
such errors using C<eval>.

=cut

sub connect
{
  my($self, $uri) = @_;
  unless(ref $uri)
  {
    require URI;
    $uri = URI->new($uri);
  }
  
  my $done = AnyEvent->condvar;

  # TODO: should we also accept http and https URLs?
  # probably.
  if($uri->scheme ne 'ws' && $uri->scheme ne 'wss')
  {
    $done->croak("URI is not a websocket");
    return $done;
  }
    
  tcp_connect $uri->host, $uri->port, sub {
    my $fh = shift;
    unless($fh)
    {
      $done->croak("unable to connect");
      return;
    }
    my $handshake = Protocol::WebSocket::Handshake::Client->new(
      url => $uri->as_string,
    );
    
    my $stream = AnyEvent::WebSocket::Client::Stream->new(
      handle => AnyEvent::Handle->new(
                                                        fh       => $fh,
        provided $uri->secure,                          tls      => 'connect',
        provided $uri->secure && !$self->ssl_no_verify, peername => $uri->host,
        provided $uri->secure && !$self->ssl_no_verify, tls_ctx  => {
                                                                                       verify => 1,
                                                                                       verify_peername => "https",
                                                          provided $self->ssl_ca_file, ca_file => $self->ssl_ca_file,
                                                        },
                                                        on_error => sub {
                                                          my ($hdl, $fatal, $msg) = @_;
                                                          if($fatal)
                                                          { $done->croak("connect error: " . $msg) }
                                                          else
                                                          { warn $msg }
                                                        },
      ),
    );
    my $hdl = $stream->handle;
    
    $hdl->push_write($handshake->to_string);

    $stream->read_cb(sub {
      $handshake->parse($_[0]{rbuf});
      if($handshake->error)
      {
        $done->croak("handshake error: " . $handshake->error);
        undef $hdl;
        undef $handshake;
        undef $done;
        undef $stream;
      }
      elsif($handshake->is_done)
      {
        undef $handshake;
        $done->send(AnyEvent::WebSocket::Connection->new(
          _stream => $stream,
        ));
        undef $hdl;
        undef $done;
        undef $stream;
      }
    });   
  }, sub { $self->timeout };
  $done;
}

package
  AnyEvent::WebSocket::Client::Stream;

use Moo;
use warnings NONFATAL => 'all';
use Scalar::Util qw( weaken );

has handle => (
  is       => 'ro',
  required => 1,
);

has read_cb => (
  is       => 'rw',
  lazy     => 1,
  default  => sub { sub { } },
);

sub BUILD
{
  my $self = shift;
  weaken $self;
  $self->handle->on_read(sub {
    $self->handle->push_read(sub {
      $self->read_cb->(@_) if $self->read_cb;
    });
  });
}

1;

=head1 CAVEATS

This is pretty simple minded and there are probably WebSocket features
that you might like to use that aren't supported by this distribution.
Patches are encouraged to improve it.

=head1 SEE ALSO

=over 4

=item *

L<AnyEvent::WebSocket::Connection>

=item *

L<AnyEvent>

=item *

L<URI::ws>

=item *

L<URI::wss>

=item *

L<Protocol::WebSocket>

=item *

L<RFC 6455 The WebSocket Protocol|http://tools.ietf.org/html/rfc6455>

=back

=cut
