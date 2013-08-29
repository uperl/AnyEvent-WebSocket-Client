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
  is      => 'rw',
  default => sub { 30 },
);

my $hdl;

=head1 METHODS

=head2 $client-E<gt>connect($uri)

Open a connection to the web server and open a WebSocket to the resource
defined by the given URL.  The URL may be either an instance of L<URI::ws>
or a string that represents a legal WebSocket URL.

Only insecure (unencrypted) WebSockets are supported, but I hope to have
that limitation corrected soon.

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

  if($uri->scheme eq 'wss')
  {
    $done->croak("Secure WebSockets not supported");
    return $done;
  }
  elsif($uri->scheme ne 'ws')
  {
    $done->croak("URI is not a websocket");
    return $done;
  }
    
  tcp_connect $uri->host, $uri->port, sub {
    my $fh = shift;
    $done->croak("unable to connect") unless $fh;
    my $handshake = Protocol::WebSocket::Handshake::Client->new(
      url => $uri->as_string,
    );
    
    $hdl = AnyEvent::Handle->new(fh => $fh);
    $hdl->push_write($handshake->to_string);
    
    $hdl->on_read(sub {
      return unless $handshake;
      $hdl->push_read(sub {
        return unless $handshake;
        $handshake->parse($_[0]{rbuf});
        if($handshake->error)
        {
          $done->croak("handshake error: " . $handshake->error);
          undef $hdl;
          undef $handshake;
          undef $done;
        }
        elsif($handshake->is_done)
        {
          undef $hdl;
          undef $handshake;
          $done->send(AnyEvent::WebSocket::Connection->new(
            _handle => AnyEvent::Handle->new(fh => $fh),
          ));
          undef $done;
        }
      })
    });
    
  }, sub { $self->timeout };
  $done;
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

L<Protocol::WebSocket>

=item *

L<RFC 6455 The WebSocket Protocol|http://tools.ietf.org/html/rfc6455>

=back

=cut
