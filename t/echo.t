use strict;
use warnings;
no warnings 'deprecated';
use v5.10;
use utf8;
BEGIN { eval q{ use EV } }
use AnyEvent::Handle;
use AnyEvent::Socket qw( tcp_server);
use AnyEvent::WebSocket::Client;
use Protocol::WebSocket::Handshake::Server;
use Protocol::WebSocket::Frame;
use Test::More tests => 8;

our $timeout = AnyEvent->timer( after => 5, cb => sub {
  diag "timeout!";
  exit 2;
});

my $hdl;

my $server_cv = AnyEvent->condvar;

tcp_server undef, undef, sub {
  my $handshake = Protocol::WebSocket::Handshake::Server->new;
  my $frame     = Protocol::WebSocket::Frame->new;
  
  $hdl = AnyEvent::Handle->new( fh => shift );
  
  $hdl->on_read(
    sub {
      my $chunk = $_[0]{rbuf};
      $_[0]{rbuf} = '';

      unless($handshake->is_done) {
        $handshake->parse($chunk);
        if($handshake->is_done)
        {
          $hdl->push_write($handshake->to_string);
        }
        return;
      }
      
      $frame->append($chunk);
      
      while(defined(my $message = $frame->next)) {
        next if !$frame->is_text && !$frame->is_binary;
        #$DB::single = 1;
        #$message = encode('UTF-8', $message);

        $hdl->push_write($frame->new("$message")->to_bytes);
        
        if($message eq 'quit')
        {
          $hdl->push_write($frame->new(type => 'close')->to_bytes);
          $hdl->push_shutdown;
        }
      }
    }
  );
}, sub {
  my($fh, $host, $port) = @_;
  $server_cv->send($port);
};

my $port = $server_cv->recv;
note "port = $port";

my $client = AnyEvent::WebSocket::Client->new;

my $connection = $client->connect("ws://127.0.0.1:$port/echo")->recv;
isa_ok $connection, 'AnyEvent::WebSocket::Connection';

my $done = AnyEvent->condvar;

my $quit_cv = AnyEvent->condvar;
$connection->on_finish(sub {
  $quit_cv->send("finished");
});

for my $testcase (
  {label => "single character", data => "a"},
  {label => "5k bytes", data => "a" x 5000},
  {label => "empty", data => ""},
  {label => "0", data => 0},
  {label => "utf8 charaters", data => 'ＵＴＦ８ ＷＩＤＥ ＣＨＡＲＡＣＴＥＲＳ'},

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

is $quit_cv->recv, "finished", "friendly disconnect";

