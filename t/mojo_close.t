use lib 't/lib';
use Test2::Require::Module 'EV';
use Test2::Require::Module 'Mojolicious' => '3.0';
use Test2::Require::Module 'Mojolicious::Lite';
use Test2::Plugin::AnyEvent::Timeout;
use Test2::V0 -no_srand => 1;
use Test2::Tools::WebSocket::Mojo qw( start_mojo );
use AnyEvent::WebSocket::Client;
use Mojolicious::Lite;

app->log->level('fatal');

my $close_cv = AE::cv;
my $closed = 0;

websocket '/echo' => sub {
  my($self) = shift;
  $self->on(message => sub {
    my($self, $payload) = @_;
    $self->send($payload);
  });
  $self->on(finish => sub {
    my ($ws, $code, $reason) = @_;
    $closed = 1;
    $close_cv->send($code, $reason);
  });
};

my ($server, $port) =  start_mojo(app => app());

my $client = AnyEvent::WebSocket::Client->new;

my $connection = $client->connect("ws://127.0.0.1:$port/echo")->recv;
isa_ok $connection, 'AnyEvent::WebSocket::Connection';

my $quit_cv = AnyEvent->condvar;
$connection->on(finish => sub {
  $quit_cv->send("finished");
});

for my $testcase (
  {label => "single character", data => "a"},
  {label => "quit", data => "quit"},
)
{
  my $cv = AnyEvent->condvar;
  $connection->on(next_message => sub {
    my $message = pop->decoded_body;
    $cv->send($message);
  });
  $connection->send($testcase->{data});
  is $cv->recv, $testcase->{data}, "$testcase->{label}: echo succeeds";
}

$connection->close;
$close_cv->recv;

is $closed, 1, "closed";

done_testing;
