package AnyEvent::WebSocket::Connection;

use strict;
use warnings;
use v5.10;
use Moo;
use warnings NONFATAL => 'all';
use Protocol::WebSocket::Frame;
use Scalar::Util qw( weaken );
use Encode qw(decode);
use AnyEvent::WebSocket::Message;
use Carp qw( croak );

# ABSTRACT: WebSocket connection for AnyEvent
# VERSION

=head1 SYNOPSIS

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
 
 # close an opened connection
 # (can do this either inside or outside of
 # a callback)
 use AnyEvent::WebSocket::Connection 0.10; # requires 0.10
 $connection->close;

(See L<AnyEvent::WebSocket::Client> on how to create
a connection)

=head1 DESCRIPTION

This class represents a WebSocket connection with a remote
server (or in the future perhaps a client).

If the connection object falls out of scope then the connection
will be closed gracefully.

This class was created for a client to connect to a server 
via L<AnyEvent::WebSocket::Client>, but it may be useful to
reuse it for a server to interact with a client if a
C<AnyEvent::WebSocket::Server> is ever created (after the
handshake is complete, the client and server look pretty
much the same).

=cut

has _stream => (
  is => 'ro',
  required => 1,
);

has _handle => (
  is       => 'ro',
  lazy     => 1,
  default  => sub { shift->_stream->handle },
  weak_ref => 1,
);

foreach my $type (qw( each_data next_data finish ))
{
  has "_${type}_cb" => (
    is       => 'ro',
    init_arg => undef,
    default  => sub { [] },
  );
}

sub BUILD
{
  my $self = shift;
  weaken $self;
  my $finish = sub {
    $_->($self) for @{ $self->_finish_cb };
  };
  $self->_handle->on_error($finish);
  $self->_handle->on_eof($finish);

  my $frame = Protocol::WebSocket::Frame->new;
  
  $self->_stream->read_cb(sub {
    $frame->append($_[0]{rbuf});
    while(defined(my $body = $frame->next_bytes))
    {
      if($frame->is_text || $frame->is_binary)
      {
        my $message = AnyEvent::WebSocket::Message->new(
          body   => $body,
          opcode => $frame->opcode,
        );
      
        $_->($self, $message) for @{ $self->_next_data_cb };
        @{ $self->_next_data_cb } = ();
        $_->($self, $message) for @{ $self->_each_data_cb };
      }
    }
  });
}

=head1 METHODS

=head2 $connection-E<gt>send($message)

Send a message to the other side.

=cut

sub send
{
  my $self = shift;
  $self->_handle->push_write(
    Protocol::WebSocket::Frame->new(shift)->to_bytes
  );
  $self;
}

=head2 $connection-E<gt>on($event => $cb)

Register a callback to a particular event.

For each event C<$connection> is the L<AnyEvent::WebSocket::Connection> and
and C<$message> is an L<AnyEvent::WebSocket::Message> (if available).

=head3 each_message

 $cb->($connection, $message)

Called each time a message is received from the WebSocket.

=head3 next_message

 $cb->($connection, $message)

Called only for the next message received from the WebSocket.

=head3 finish

 $cb->($connection)

Called when the connection is terminated

=head3 

=cut

sub on
{
  my($self, $event, $cb) = @_;
  
  if($event eq 'next_message')
  {
    push @{ $self->_next_data_cb }, $cb;
  }
  elsif($event eq 'each_message')
  {
    push @{ $self->_each_data_cb }, $cb;
  }
  elsif($event eq 'finish')
  {
    push @{ $self->_finish_cb }, $cb;
  }
  else
  {
    croak "unrecongized event: $event";
  }
  $self;
}

=head2 $connection-E<gt>on_each_message($cb)

Register a callback to be called on each subsequent message received.
The message itself will be passed in as the only parameter to the
callback.
The message is a decoded text string.

=cut

sub on_each_message
{
  my($self, $cb) = @_;
  $self->on(each_message => sub {
    $cb->(decode("UTF-8",pop->body));
  });
  $self;
}

=head2 $connection-E<gt>on_next_message($cb)

Register a callback to be called the next message received.
The message itself will be passed in as the only parameter to the
callback.
The message is a decoded text string.

=cut

sub on_next_message
{
  my($self, $cb) = @_;
  $self->on(next_message => sub {
    $cb->(decode("UTF-8",pop->body));
  });
  $self;
}

=head2 $connection-E<gt>on_finish($cb)

Register a callback to be called when the connection is closed.

=cut

sub on_finish
{
  my($self, $cb) = @_;
  $self->on(finish => $cb);
  $self;
}

=head2 $connection-E<gt>close

Close the connection.

=cut

sub close
{
  my($self) = @_;

  $self->_handle->push_write(Protocol::WebSocket::Frame->new(type => 'close')->to_bytes);
  $self->_handle->push_shutdown;
}

1;

=head1 SEE ALSO

=over 4

=item *

L<AnyEvent::WebSocket::Client>

=item *

L<AnyEvent>

=back

=cut
