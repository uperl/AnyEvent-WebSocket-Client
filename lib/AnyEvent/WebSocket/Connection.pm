package AnyEvent::WebSocket::Connection;

use strict;
use warnings;
use v5.10;
use Moo;
use warnings NONFATAL => 'all';
use Protocol::WebSocket::Frame;
use Scalar::Util qw( weaken );
use Encode ();
use AnyEvent::WebSocket::Message;
use Carp qw( croak carp );

# ABSTRACT: WebSocket connection for AnyEvent
# VERSION

=head1 SYNOPSIS

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
 
 # close an opened connection
 # (can do this either inside or outside of
 # a callback)
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

=head1 ATTRIBUTES

=head2 handle

The underlying AnyEvent::Handle object used for the connection.

Usually only useful for creating server connections, see below.

=cut

has handle => (
  is       => 'ro',
  required => 1,
);

=head2 read_cb

The callback called when raw data arrives on the connection.

Usually only useful for creating server connections, see below.

=cut

has read_cb => (
  is       => 'rw',
  lazy     => 1,
  default  => sub { sub { } },
);

foreach my $type (qw( each_message next_message finish ))
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
  $self->handle->on_read(sub {
    $self->handle->push_read(sub {
      $self->read_cb->(@_) if $self->read_cb;
    });
  });
}

=head1 METHODS

=head2 $connection-E<gt>send($message)

Send a message to the other side.  C<$message> may either be a string
(in which case a text message will be sent), or an instance of
L<AnyEvent::WebSocket::Message>.

=cut

sub send
{
  my($self, $message) = @_;
  my $frame;
  if(ref $message)
  {
    $DB::single = 1;
    $frame = Protocol::WebSocket::Frame->new($message->body);
    $frame->opcode($message->opcode);
  }
  else
  {
    $frame = Protocol::WebSocket::Frame->new($message);
  }
  $self->handle->push_write($frame->to_bytes);
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
    push @{ $self->_next_message_cb }, $cb;
  }
  elsif($event eq 'each_message')
  {
    push @{ $self->_each_message_cb }, $cb;
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

=head2 $connection-E<gt>close

Close the connection.

=cut

sub close
{
  my($self) = @_;

  $self->handle->push_write(Protocol::WebSocket::Frame->new(type => 'close')->to_bytes);
  $self->handle->push_shutdown;
}

=head2 $connection-E<gt>post_handshake

The enables Connection to take over processing of new data sent through the
connection.

Usually only useful for creating server connections, see below.

=cut

sub post_handshake
{
  my $self = shift;
  weaken $self;
  my $finish = sub {
    $_->($self) for @{ $self->_finish_cb };
  };
  $self->handle->on_error($finish);
  $self->handle->on_eof($finish);

  my $frame = Protocol::WebSocket::Frame->new;
  
  $self->read_cb(sub {
    $frame->append($_[0]{rbuf});
    while(defined(my $body = $frame->next_bytes))
    {
      if($frame->is_text || $frame->is_binary)
      {
        my $message = AnyEvent::WebSocket::Message->new(
          body   => $body,
          opcode => $frame->opcode,
        );
      
        $_->($self, $message) for @{ $self->_next_message_cb };
        @{ $self->_next_message_cb } = ();
        $_->($self, $message) for @{ $self->_each_message_cb };
      }
    }
  });
}

=head1 SERVER CONNECTIONS

Although written originally to work with L<AnyEvent::WebSocket::Client>,
this class was designed to be used for either client or server WebSocket
connections.  For details, contact the author and/or take a look at the
source for L<AnyEvent::WebSocket::Client> and the examples that come with
L<Protocol::WebSocket>.

=head1 DEPRECATED METHODS

The methods in this section are deprecated and may be removed from a
future version of this class.  They should not be used for new code,
and are only remain documented here to aid in understanding legacy
code that use them.

=head2 $connection-E<gt>on_each_message($cb)

Register a callback to be called on each subsequent message received.
The message itself will be passed in as the only parameter to the
callback.
The message is a decoded text string.

=cut

sub on_each_message
{
  my($self, $cb) = @_;
  carp "on_each_message is deprecated" if warnings::enabled('deprecated');
  $self->on(each_message => sub {
    $cb->(Encode::decode("UTF-8",pop->body));
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
  carp "on_next_message is deprecated" if warnings::enabled('deprecated');
  $self->on(next_message => sub {
    $cb->(Encode::decode("UTF-8",pop->body));
  });
  $self;
}

=head2 $connection-E<gt>on_finish($cb)

Register a callback to be called when the connection is closed.

=cut

sub on_finish
{
  my($self, $cb) = @_;
  carp "on_finish is deprecated" if warnings::enabled('deprecated');
  $self->on(finish => $cb);
  $self;
}

1;

=head1 SEE ALSO

=over 4

=item *

L<AnyEvent::WebSocket::Client>

=item *

L<AnyEvent::WebSocket::Message>

=item *

L<AnyEvent>

=item *

L<RFC 6455 The WebSocket Protocol|http://tools.ietf.org/html/rfc6455>

=back

=cut

