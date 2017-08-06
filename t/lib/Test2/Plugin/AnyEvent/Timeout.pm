package Test2::Plugin::AnyEvent::Timeout;

use strict;
use warnings;
use Test2::API qw( context );
use AnyEvent;

our $timeout;

sub import
{
  return if defined $timeout;
  
  $timeout = AnyEvent->timer(
    after => 30,
    cb => sub {
      my $ctx = context();
      $ctx->bail("Test exceeded timeout of 30s");
      $ctx->release;
    },
  );
}

1;
