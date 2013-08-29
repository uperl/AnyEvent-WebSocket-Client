use strict;
use warnings;
use AnyEvent::WebSocket::Client;
use Test::More;
BEGIN { plan skip_all => 'Requires Mojolicious::Lite' unless eval q{ use Mojolicious::Lite; 1 } }

app->log->level('fatal');

websocket '/count/:num' => sub {
  my($self) = shift;

  my $max = $self->param('num');
  my $counter = 1;
  
  $self->on(message => sub {
   my($self, $payload) = @_;
     note "send $counter";
    $self->send($counter++);
    if($counter >= $max)
    {
      $self->finish;
    }
  });
};

my $server = Mojo::Server::Daemon->new;
$server->app(app);
$server->listen(["http://127.0.0.1:3000"]);
$server->start;

my $client = AnyEvent::WebSocket::Client->new;

my $connection = $client->connect("ws://127.0.0.1:3000/count/10")->recv;
isa_ok $connection, 'AnyEvent::WebSocket::Client::Connection';

$connection->send('ping');

my $last;

$connection->on_each_message(sub {
  my $message = shift;
  note "recv $message";
  $connection->send('ping');
  $last = $message;
});

my $done = AnyEvent->condvar;

$connection->on_finish(sub {
  $done->send(1);
});

is $done->recv, '1', 'friendly disconnect';

is $last, 9, 'last = 9';

done_testing;
