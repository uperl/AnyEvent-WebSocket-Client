package AnyEvent::WebSocket::Message;

use strict;
use warnings;
use v5.10;
use Moo;
use warnings NONFATAL => 'all';

# ABSTRACT: WebSocket message for AnyEvent
# VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 ATTRIBUTES

=head2 body

=head2 opcode

=cut

has body => ( is => 'ro', required => 1 );
has opcode => ( is => 'ro', required => 1 );

=head1 METHODS

=head2 is_text

=head2 is_binary

=head2 is_close

=head2 is_ping

=head2 is_pong

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

=back

=cut
