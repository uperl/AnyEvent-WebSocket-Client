use lib 't/lib';
use Test2::Require::Module 'Capture::Tiny';
use Test2::Require::Module 'EV';
use Test2::Require::Module 'Mojolicious' => '3.0';
use Test2::Require::Module 'Mojolicious::Lite';
use Test2::Require::Module 'Test::Memory::Cycle';
use Test2::Require::Module 'Devel::Cycle';
use Test2::Plugin::AnyEvent::Timeout;
use Test2::V0 -no_srand => 1;
use Test2::Tools::WebSocket::Mojo qw( start_mojo );
use AnyEvent::WebSocket::Client;
use Mojolicious::Lite;
use Capture::Tiny qw( capture_stderr );
use Test::Memory::Cycle;

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


my ($server, $port) =  start_mojo(app => app());

my $client = AnyEvent::WebSocket::Client->new;

my $connection = $client->connect("ws://127.0.0.1:$port/foo")->recv;
isa_ok $connection, 'AnyEvent::WebSocket::Connection';

is $finished, 0, 'finished = 0';

$connection->send('foo');

is $finished, 0, 'finished = 0';

note capture_stderr { memory_cycle_ok $connection };
undef $connection;

$server->ioloop->one_tick;
$server->ioloop->one_tick;

is $finished, 1, 'finished = 1';

done_testing;
