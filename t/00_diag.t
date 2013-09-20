use strict;
use warnings;
use v5.10;
use Test::More tests => 1;

my @modules = sort qw(
  AnyEvent
  AnyEvent::Socket
  Capture::Tiny
  Devel::Cycle
  EV
  Mojolicious
  Moo
  PerlX::Maybe 
  PerlX::Maybe::XS
  Protocol::WebSocket
  Scalar::Util
  Test::More
  Test::Memory::Cycle
  URI
  URI::ws
);

diag '';
diag '';
diag '';

foreach my $module (@modules)
{
  if(eval qq{ use $module; 1 })
  {
    $DB::single = 1;
    diag sprintf "%-20s %s", $module, eval qq{ \$$module\::VERSION } // 'undef';
  }
  else
  {
    diag sprintf "%20s none";
  }
}

diag '';
diag '';
diag '';

pass 'okay';
