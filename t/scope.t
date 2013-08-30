use strict;
use warnings;
use Test::More;
BEGIN { plan skip_all => 'Requires Capture::Tiny' unless eval q{ use Capture::Tiny qw( capture_stderr ); 1 } }
BEGIN { plan skip_all => 'Requires EV' unless eval q{ use EV; 1 } }
BEGIN { plan skip_all => 'Requires Mojolicious::Lite' unless eval q{ use Mojolicious::Lite; 1 } }
BEGIN { plan skip_all => 'Requires Test::Memory::Cycle' unless eval q{ use Test::Memory::Cycle; 1 } }
use AnyEvent::WebSocket::Client;

app->log->level('fatal');

my $finished = 0;

websocket '/foo' => sub {
  my $self = shift;
  $self->on(message => sub {
    my($self, $payload) = @_;
    $self->send($payload);
  });
  $self->on(finish => sub {
    $finished = 1;
    note 'FINISH';
  });
};

my $server = Mojo::Server::Daemon->new;
my $port = $server->ioloop->generate_port;
note "port = $port";
$server->app(app);
$server->listen(["http://127.0.0.1:$port"]);
$server->start;

our $timeout = AnyEvent->timer( after => 5, cb => sub {
  diag "timeout!";
  exit 2;
});

my $client = AnyEvent::WebSocket::Client->new;

my $connection = $client->connect("ws://127.0.0.1:$port/foo")->recv;
isa_ok $connection, 'AnyEvent::WebSocket::Connection';

is $finished, 0, 'finished = 0';

$connection->send('foo');

is $finished, 0, 'finished = 0';

use Devel::Cycle;
note capture_stderr { memory_cycle_ok $connection };
undef $connection;

$server->ioloop->one_tick;
$server->ioloop->one_tick;

is $finished, 1, 'finished = 1';

done_testing;
