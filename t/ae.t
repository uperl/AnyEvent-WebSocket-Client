use strict;
use warnings;
BEGIN { eval q{ use EV } }
use AnyEvent::WebSocket::Client;
use Test::More;
use FindBin ();
use lib $FindBin::Bin;
use testlib::Server;

testlib::Server->set_timeout;

my $counter;
my $max;
my $last_handshake;

my $uri = testlib::Server->start_server(
  handshake => sub {  # handshake
    my $opt = { @_ };
    $counter = 1;
    $max = 15;
    note "max = $max";
    $last_handshake = $opt->{handshake};
    note "resource = " . $opt->{handshake}->req->resource_name;
    note "version  = " . $opt->{handshake}->version;
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

subtest basic => sub {

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
};

subtest 'version' => sub {

  my $connection = AnyEvent::WebSocket::Client->new(
    protocol_version => 'draft-ietf-hybi-10',
  )->connect($uri)->recv;

  is $last_handshake->version, 'draft-ietf-hybi-10', 'server side protool_version = draft-ietf-hybi-10';
};

done_testing;
