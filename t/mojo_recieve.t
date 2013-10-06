use strict;
use warnings;
use AnyEvent::WebSocket::Client;
use Test::More;
BEGIN { plan skip_all => 'Requires EV' unless eval q{ use EV; 1 } }
BEGIN { plan skip_all => 'Requires Mojolicious 3.0' unless eval q{ use Mojolicious 3.0; 1 } }
BEGIN { plan skip_all => 'Requires Mojolicious::Lite' unless eval q{ use Mojolicious::Lite; 1 } }
use lib "t";
use testlib::Mojo qw(start_mojo);
use utf8;
use Encode qw(encode);

my @test_cases = (
  { send => { binary => "hoge"}, recv_exp => ["hoge", "binary"] },
  { send => { text   => "foobar"}, recv_exp => ["foobar", "text"] },
  { send => { binary => encode("utf8", "ＵＴＦー８") }, recv_exp => [encode("utf8", "ＵＴＦー８"), "binary"] },
  { send => { text   => encode("utf8", "ＵＴＦー８") }, recv_exp => [encode("utf8", "ＵＴＦー８"), "text"] },
);

app->log->level('fatal');

websocket '/data' => sub {
  my($self) = shift;
  $self->on(message => sub {
    my($self, $index) = @_;
    $self->send($test_cases[$index]{send});
  });
};

my ($server, $port) = start_mojo(app => app());

our $timeout = AnyEvent->timer( after => 5, cb => sub {
  diag "timeout!";
  exit 2;
});

my $client = AnyEvent::WebSocket::Client->new;

my $connection = $client->connect("ws://127.0.0.1:$port/data")->recv;
isa_ok $connection, 'AnyEvent::WebSocket::Connection';

{
  note("--- on_next_data()");
  my $cb_count = 0;
  for my $test_index (0 .. $#test_cases)
  {
    my $cv = AnyEvent->condvar;
    $connection->on(next_message => sub { $cb_count++; $cv->send(@_) });
    $connection->send($test_index);
    my($connection, $message) = $cv->recv;
    isa_ok $connection, 'AnyEvent::WebSocket::Connection';
    is $message->body, $test_cases[$test_index]->{recv_exp}->[0], "body = " . $message->body;
    is $message->type, $test_cases[$test_index]->{recv_exp}->[1], "type = " . $message->type;
  }
  is($cb_count, scalar(@test_cases), "callback count OK");
}

{
  note("--- on_each_data()");
  my $cv;
  my $cb_count = 0;
  $connection->on(each_message => sub { $cb_count++; $cv->send(@_) });
  for my $test_index (0 .. $#test_cases)
  {
    $cv = AnyEvent->condvar;
    $connection->send($test_index);
    my($connection, $message) = $cv->recv;
    isa_ok $connection, 'AnyEvent::WebSocket::Connection';
    is $message->body, $test_cases[$test_index]->{recv_exp}->[0], "body = " . $message->body;
    is $message->type, $test_cases[$test_index]->{recv_exp}->[1], "type = " . $message->type;
  }
  is($cb_count, scalar(@test_cases), "callback count OK");
}

done_testing();


