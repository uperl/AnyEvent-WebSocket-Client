package AnyEvent::WebSocket;

use strict;
use warnings;
use v5.10;
use mop;
use Protocol::WebSocket::Frame;
use Scalar::Util qw( weaken );
use Encode ();
use AnyEvent;
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
server or a client.

If the connection object falls out of scope then the connection
will be closed gracefully.

This class was created for a client to connect to a server 
via L<AnyEvent::WebSocket::Client>, but it may be useful to
reuse it for a server to interact with a client. After the
handshake is complete, the client and server look pretty
much the same.

=head1 ATTRIBUTES

=head2 handle

The underlying L<AnyEvent::Handle> object used for the connection.
WebSocket handshake MUST be already completed using this handle.
You should not use the handle directly after creating L<AnyEvent::WebSocket::Connection> object.

Usually only useful for creating server connections, see below.

=cut

class Connection {

  has $!handle is ro = die "handle is required";

=head2 masked

If set to true, it masks outgoing frames. The default is false.

=cut

  has $!masked is ro = 0;

  # init_arg = undef ??
  has $!_each_message_cb is ro = [];
  has $!_next_message_cb is ro = [];
  has $!_finish_cb is ro = [];

  has $!_is_read_open is rw = 1;
  has $!_is_write_open is rw = 1;
  has $!_is_finished is rw = 0;

  method BUILD { $self->_legacy_build }

sub ::AnyEvent::WebSocket::Connection::_legacy_build
{
  my $self = shift;
  weaken $self;
  my $finish = sub {
    my $strong_self = $self; # preserve $self because otherwise $self can be destroyed in the callbacks.
    return if $self->_is_finished;
    $self->_is_finished(1);
    $self->handle->push_shutdown;
    $self->_is_read_open(0);
    $self->_is_write_open(0);
    $_->($self) for @{ $self->_finish_cb };
  };
  $self->handle->on_error($finish);
  $self->handle->on_eof($finish);

  my $frame = Protocol::WebSocket::Frame->new;

  my $read_cb = sub {
    my ($handle) = @_;
    local $@;
    my $strong_self = $self; # preserve $self because otherwise $self can be destroyed in the callbacks
    my $success = eval
    {
      $frame->append($handle->{rbuf});
      while(defined(my $body = $frame->next_bytes))
      {
        next if !$self->_is_read_open; # not 'last' but 'next' in order to consume data in $frame buffer.
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
        elsif($frame->is_close)
        {
          $self->_is_read_open(0);
          $self->close();
        }
        elsif($frame->is_ping)
        {
          $self->send(AnyEvent::WebSocket::Message->new(opcode => 10, body => $body));
        }
      }
      1; # succeed to parse.
    };
    if(!$success)
    {
      $self->handle->push_shutdown;
      $self->_is_write_open(0);
      $self->_is_read_open(0);
    }
  };

  # Delay setting on_read callback. This is necessary to make sure all
  # received data are handled by each_message and/or next_message
  # callbacks. If there is some data in rbuf, changing the on_read
  # callback makes the callback fire, but there is of course no
  # each_message/next_message callback to receive the message yet.
  $self->handle->on_read(undef);
  my $idle_w; $idle_w = AnyEvent->idle(cb => sub {
    undef $idle_w;
    if(defined($self))
    {
      $read_cb->($self->handle); # make sure to read remaining data in rbuf.
      $self->handle->on_read($read_cb);
    }
  });
}

=head1 METHODS

=head2 $connection-E<gt>send($message)

Send a message to the other side.  C<$message> may either be a string
(in which case a text message will be sent), or an instance of
L<AnyEvent::WebSocket::Message>.

=cut

method send($message)
{
  my $frame;
  
  return $self if !$!_is_write_open;
  
  if(ref $message)
  {
    $frame = Protocol::WebSocket::Frame->new(buffer => $message->body, masked => $!masked);
    $frame->opcode($message->opcode);
  }
  else
  {
    $frame = Protocol::WebSocket::Frame->new(buffer => $message, masked => $!masked);
  }
  $!handle->push_write($frame->to_bytes);
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

method on($event, $cb)
{
  if($event eq 'next_message')
  {
    push @{ $!_next_message_cb }, $cb;
  }
  elsif($event eq 'each_message')
  {
    push @{ $!_each_message_cb }, $cb;
  }
  elsif($event eq 'finish')
  {
    push @{ $!_finish_cb }, $cb;
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

method close
{
  $self->send(AnyEvent::WebSocket::Message->new(opcode => 8, body => ""));
  $!handle->push_shutdown;
  $!_is_write_open = 0;
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

method on_each_message($cb)
{
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

method on_next_message($cb)
{
  carp "on_next_message is deprecated" if warnings::enabled('deprecated');
  $self->on(next_message => sub {
    $cb->(Encode::decode("UTF-8",pop->body));
  });
  $self;
}

=head2 $connection-E<gt>on_finish($cb)

Register a callback to be called when the connection is closed.

=cut

method on_finish($cb)
{
  carp "on_finish is deprecated" if warnings::enabled('deprecated');
  $self->on(finish => $cb);
  $self;
}

} # end class

1;

=head1 SEE ALSO

=over 4

=item *

L<AnyEvent::WebSocket::Client>

=item *

L<AnyEvent::WebSocket::Message>

=item *

L<AnyEvent::WebSocket::Server>

=item *

L<AnyEvent>

=item *

L<RFC 6455 The WebSocket Protocol|http://tools.ietf.org/html/rfc6455>

=back

=cut

