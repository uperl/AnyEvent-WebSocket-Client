use strict;
use warnings;
use Test::More;
BEGIN { eval q{ use EV } }
BEGIN { plan skip_all => 'test requires Test::Warn' unless eval q{ use Test::Warn; 1 } }
use AnyEvent::WebSocket::Client;
use AnyEvent::Socket qw( tcp_server );
use Protocol::WebSocket::Handshake::Server;
use Protocol::WebSocket::Frame;

plan tests => 4;

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
        # lalalalala not listening
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

warning_like { $connection->on_next_message(sub { }) } qr{on_next_message is deprecated}, "deprecation warning for on_next_message";
warning_like { $connection->on_each_message(sub { }) } qr{on_each_message is deprecated}, "deprecation warning for on_each_message";
warning_like { $connection->on_finish(sub { }) } qr{on_finish is deprecated}, "deprecation warning for on_finish";
