use strict;
use warnings;
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
  handshake => sub {  # handshake
    my $opt = { @_ };
    $counter = 1;
    $max = 15;
    note "max = $max";
    note "resource = " . $opt->{handshake}->req->resource_name;
    if($opt->{handshake}->req->resource_name =~ /\/count\/(\d+)/)
    { $max = $1 }
    note "max = $max";
  },
  message => sub {  # message
    my $opt = { @_ };
    eval q{
      note "send $counter";
      $opt->{hdl}->push_write($opt->{frame}->new($counter++)->to_bytes);
      if($counter >= $max)
      {
        $opt->{hdl}->push_write($opt->{frame}->new(type => 'close')->to_bytes);
        $opt->{hdl}->push_shutdown;
      }
    };
  },
);

$uri->path('/count/10');
note $uri;

my $connection = AnyEvent::WebSocket::Client->new->connect($uri)->recv;
isa_ok $connection, 'AnyEvent::WebSocket::Connection';

my $done = AnyEvent->condvar;

$connection->send('ping');

my $last;

$connection->on(each_message => sub {
  my $message = pop->body;
  note "recv $message";
  $connection->send('ping');
  $last = $message;
});

$connection->on(finish => sub {
  $done->send(1);
});

is $done->recv, '1', 'friendly disconnect';

is $last, 9, 'last = 9';
