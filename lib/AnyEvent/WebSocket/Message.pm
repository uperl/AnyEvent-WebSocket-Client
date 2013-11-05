package AnyEvent::WebSocket;

use strict;
use warnings;
use v5.10;
use mop;
use Encode ();

# ABSTRACT: WebSocket message for AnyEvent
# VERSION

=head1 SYNOPSIS

 $connection->send(
   AnyEvent::WebSocket::Message->new(body => "some message"),
 );

 $connection->on(each_message => sub {
   my($connection, $message) = @_;
   if($message->is_text || $message->is_binary)
   {
     my $body = $message->body;
   }
 });

=head1 DESCRIPTION

Instances of this class represent a message passed through the WebSocket
from the other end.

=head1 ATTRIBUTES

=head2 body

The body or payload of the message.

=head2 opcode

The integer code for the type of message.

=cut

class Message {

  has $!body is ro = die "body is required";
  has $!opcode is ro = 1;

=head1 METHODS

=head2 $message-E<gt>decoded_body

Returns the body decoded from UTF-8.

=cut

  method decoded_body
  {
    Encode::decode("UTF-8", $self->body)
  }

=head2  $message-E<gt>is_text

True if the message is text.

=head2  $message-E<gt>is_binary

True if the message is binary.

=head2  $message-E<gt>is_close

True if the message is a close message.

=head2  $message-E<gt>is_ping

True if the message is a ping.

=head2  $message-E<gt>is_pong

True if the message is a pong.

=cut

  method is_text   { $!opcode == 1 }
  method is_binary { $!opcode == 2 }
  method is_close  { $!opcode == 8 }
  method is_ping   { $!opcode == 9 }
  method is_pong   { $!opcode == 10 }

} # end class

1;

=head1 SEE ALSO

=over 4

=item *

L<AnyEvent::WebSocket::Client>

=item *

L<AnyEvent::WebSocket::Connection>

=item *

L<AnyEvent::WebSocket::Server>

=item *

L<AnyEvent>

=item *

L<RFC 6455 The WebSocket Protocol|http://tools.ietf.org/html/rfc6455>

=back

=cut
