package AnyEvent::WebSocket::Message;

use strict;
use warnings;
use v5.10;
use Moo;
use warnings NONFATAL => 'all';
use Encode ();

# ABSTRACT: WebSocket message for AnyEvent
# VERSION

=head1 SYNOPSIS

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

has body => ( is => 'ro', required => 1 );
has opcode => ( is => 'ro', required => 1 );

=head1 METHODS

=head2 $message-E<gt>decoded_body

Returns the body decoded from UTF-8.

=cut

sub decoded_body
{
  Encode::decode("UTF-8", shift->body)
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

sub is_text   { $_[0]->opcode == 1 }
sub is_binary { $_[0]->opcode == 2 }
sub is_close  { $_[0]->opcode == 8 }
sub is_ping   { $_[0]->opcode == 9 }
sub is_pong   { $_[0]->opcode == 10 }

1;

=head1 SEE ALSO

=over 4

=item *

L<AnyEvent::WebSocket::Client>

=item *

L<AnyEvent::WebSocket::Connection>

=item *

L<AnyEvent>

=item *

L<RFC 6455 The WebSocket Protocol|http://tools.ietf.org/html/rfc6455>

=back

=cut
