use strict;
use warnings;
use v5.10;
BEGIN { eval q{ use EV } }
use AnyEvent::Handle;
use AnyEvent::Socket qw( tcp_server);
use AnyEvent::WebSocket::Client;
use Protocol::WebSocket::Handshake::Server;
use Protocol::WebSocket::Frame;
use Test::More tests => 3;

our $timeout = AnyEvent->timer( after => 5, cb => sub {
  diag "timeout!";
  exit 2;
});

my $hdl;

my $server_cv = AnyEvent->condvar;

tcp_server undef, undef, sub {
  my $handshake = Protocol::WebSocket::Handshake::Server->new;
  my $frame     = Protocol::WebSocket::Frame->new;
  
  my $counter = 1;
  my $max = 15;
  
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
          note "max = $max";
          note "resource = " . $handshake->req->resource_name;
          if($handshake->req->resource_name =~ /\/count\/(\d+)/)
          { $max = $1 }
          note "max = $max";
        }
        return;
      }
      
      $frame->append($chunk);
      
      while(defined(my $message = $frame->next)) {
        note "send $counter";
        $hdl->push_write($frame->new($counter++)->to_bytes);
        if($counter >= $max)
        {
          undef $hdl;
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

my $connection = $client->connect("ws://127.0.0.1:$port/count/10")->recv;
isa_ok $connection, 'AnyEvent::WebSocket::Connection';

my $done = AnyEvent->condvar;

$connection->send('ping');

my $last;

$connection->on_each_message(sub {
  my $message = shift;
  note "recv $message";
  $connection->send('ping');
  $last = $message;
});

$connection->on_finish(sub {
  $done->send(1);
});

is $done->recv, '1', 'friendly disconnect';

is $last, 9, 'last = 9';
