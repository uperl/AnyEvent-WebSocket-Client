use strict;
use warnings;
no warnings 'deprecated';
use AnyEvent::WebSocket::Client;
use Test::More;
BEGIN { plan skip_all => 'Requires EV' unless eval q{ use EV; 1 } }
BEGIN { plan skip_all => 'Requires Mojolicious 3.0' unless eval q{ use Mojolicious 3.0; 1 } }
BEGIN { plan skip_all => 'Requires Mojolicious::Lite' unless eval q{ use Mojolicious::Lite; 1 } }
use FindBin;
use lib $FindBin::Bin;
use testlib::Mojo;
use utf8;

plan tests => 4;

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

my ($server, $port) =  testlib::Mojo->start_mojo(app => app());

our $timeout = AnyEvent->timer( after => 5, cb => sub {
  diag "timeout!";
  exit 2;
});

my $client = AnyEvent::WebSocket::Client->new;

my $connection = $client->connect("ws://127.0.0.1:$port/echo")->recv;
isa_ok $connection, 'AnyEvent::WebSocket::Connection';

my $quit_cv = AnyEvent->condvar;
$connection->on_finish(sub {
  $quit_cv->send("finished");
});

for my $testcase (
  {label => "single character", data => "a"},
  {label => "quit", data => "quit"},
)
{
  my $cv = AnyEvent->condvar;
  $connection->on_next_message(sub {
    my ($message) = @_;
    $cv->send($message);
  });
  $connection->send($testcase->{data});
  is $cv->recv, $testcase->{data}, "$testcase->{label}: echo succeeds";
}

$connection->close;
$close_cv->recv;

is $closed, 1, "closed";

