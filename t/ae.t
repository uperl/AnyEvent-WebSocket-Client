use strict;
use warnings;
no warnings 'deprecated';
use v5.10;
BEGIN { eval q{ use EV } }
use AnyEvent::WebSocket::Client;
use Test::More tests => 3;
use FindBin ();
use lib $FindBin::Bin;
use testlib::Server;

testlib::Server->set_timeout;

my $counter;
my $max;

my $uri = testlib::Server->start_server(
  sub {  # message
    my($frame, $message, $hdl) = @_;
    note "send $counter";
    $hdl->push_write($frame->new($counter++)->to_bytes);
    if($counter >= $max)
    {
      $hdl->push_write($frame->new(type => 'close')->to_bytes);
      $hdl->push_shutdown;
    }
  },
  sub {  # handshake
    my($handshake) = @_;
    $counter = 1;
    $max = 15;
    note "max = $max";
    note "resource = " . $handshake->req->resource_name;
    if($handshake->req->resource_name =~ /\/count\/(\d+)/)
    { $max = $1 }
    note "max = $max";
  },
);

$uri->path('/count/10');
note $uri;

my $connection = AnyEvent::WebSocket::Client->new->connect($uri)->recv;
isa_ok $connection, 'AnyEvent::WebSocket::Connection';

my $done = AnyEvent->condvar;

$connection->send('ping');

my $last;

$connection->on_each_message(sub {
  my $message = shift;
  note "recv $message";
  $connection->send('ping');
  $last = $message;
});

$connection->on_finish(sub {
  $done->send(1);
});

is $done->recv, '1', 'friendly disconnect';

is $last, 9, 'last = 9';
