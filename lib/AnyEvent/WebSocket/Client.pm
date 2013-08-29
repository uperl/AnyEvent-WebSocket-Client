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

=head1 DESCRIPTION

=head1 ATTRIBUTES

=head2 timeout

=cut

has timeout => (
  is      => 'rw',
  default => sub { 30 },
);

my $hdl;

=head1 METHODS

=head2 $client-E<gt>connect($uri)

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

=head1 SEE ALSO

L<AnyEvent::WebSocket::Connection>, L<AnyEvent>, L<URI::ws>,

=cut
