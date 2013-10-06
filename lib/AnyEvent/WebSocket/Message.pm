package AnyEvent::WebSocket::Message;

use strict;
use warnings;
use v5.10;
use Moo;
use warnings NONFATAL => 'all';

has body => ( is => 'ro', required => 1 );
has opcode => ( is => 'ro', required => 1 );

sub type
{
  shift->opcode == 1 ? 'text' : 'binary';
}

1;
