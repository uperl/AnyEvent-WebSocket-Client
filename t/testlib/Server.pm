package testlib::Server;

use strict;
use warnings;
use v5.10;
use URI;
use Test::More;
use AnyEvent::Handle;
use AnyEvent::Socket qw( tcp_server);
use Protocol::WebSocket::Handshake::Server;
use Protocol::WebSocket::Frame;

my $timeout;

sub set_timeout
{
  return if defined $timeout;
  $timeout = AnyEvent->timer( after => 5, cb => sub {
    diag "timeout!";
    exit 2;
  });
}

sub start_server
{
  my($class, $message_cb, $handshake_cb) = @_;
  my $server_cv = AnyEvent->condvar;

  tcp_server undef, undef, sub {
    my $handshake = Protocol::WebSocket::Handshake::Server->new;
    my $frame     = Protocol::WebSocket::Frame->new;
  
    my $hdl = AnyEvent::Handle->new( fh => shift );
  
    $hdl->on_read(
      sub {
        my $chunk = $_[0]{rbuf};
        $_[0]{rbuf} = '';

        unless($handshake->is_done) {
          $handshake->parse($chunk);
          if($handshake->is_done)
          {
            $hdl->push_write($handshake->to_string);
            $handshake_cb->($handshake, $hdl)
              if $handshake_cb;
          }
          return;
        }
      
        $frame->append($chunk);
      
        while(defined(my $message = $frame->next))
        {
          $message_cb->($frame, $message, $hdl);
        }
      }
    );
  }, sub {
    my($fh, $host, $port) = @_;
    $server_cv->send($port);
  };

  my $port = $server_cv->recv;
  
  my $uri = URI->new('ws://127.0.0.1/echo');
  $uri->port($port);
  note "$uri";
  $uri;
}

sub start_echo
{
  shift->start_server(sub {
    my($frame, $message, $hdl) = @_;
    
    return if !$frame->is_text && !$frame->is_binary;

    $hdl->push_write($frame->new("$message")->to_bytes);
        
    if($message eq 'quit')
    {
      $hdl->push_write($frame->new(type => 'close')->to_bytes);
      $hdl->push_shutdown;
    }
  });
}

1;
