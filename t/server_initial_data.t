use strict;
use warnings;
use v5.10;
use utf8;
BEGIN { eval q{ use EV } }
use AnyEvent;
use AnyEvent::WebSocket::Client;
use Test::More;
use FindBin ();
use lib $FindBin::Bin;
use testlib::Server;

testlib::Server->set_timeout;

my $url = testlib::Server->start_server_with_initial_messages(
  ["initial message from server"],
  sub {
    ## message callback
    my ($frame, $message, $handle) = @_;
    $handle->push_shutdown;
  }
);

my $conn = AnyEvent::WebSocket::Client->new->connect($url)->recv;
my $cv_finish = AnyEvent->condvar;
my @received_messages = ();
$conn->on(each_message => sub {
  my ($conn, $message) = @_;
  push(@received_messages, $message->body);
  $conn->send("finish");
  
});
$conn->on(finish => sub {
  $cv_finish->send();
});

$cv_finish->recv;
is_deeply(\@received_messages, ["initial message from server"],
          "client connection should receive the initial message sent from server");

done_testing;
