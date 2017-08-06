package Test2::Tools::WebSocket::Connection;

use strict;
use warnings;
use Test2::API qw( context );
use AnyEvent::Handle;
use AnyEvent::Socket qw(tcp_server);
use base qw( Exporter );

our @EXPORT_OK = qw( create_connection_pair create_connection_and_handle );

sub create_handle_pair
{
  my @ports;
  my $cv_port = AnyEvent->condvar;
  my $cv_server_fh = AnyEvent->condvar;
  my $server = tcp_server undef, undef, sub {
    my ($fh, $host, $port) = @_;
    $ports[0] = $port;
    $cv_server_fh->send($fh);
  }, sub {
    my($fh, $host, $port) = @_;
    $ports[1] = $port;
    $cv_port->send($port);
  };
  my $cv_connect = AnyEvent->condvar;
  my $a_handle = AnyEvent::Handle->new(
    connect => ["127.0.0.1", $cv_port->recv],
    on_error => sub { die "connect error: $_[2]" },
    on_connect => sub { $cv_connect->send() }
  );
  $cv_connect->recv;
  my $b_handle = AnyEvent::Handle->new(
     fh => $cv_server_fh->recv  
  );
  
  my $ctx = context();
  $ctx->note("create connection pair " . join(':', @ports));
  $ctx->release;
  
  return ($a_handle, $b_handle);
}

sub create_connection_pair
{
  my ($a_options_ref, $b_options_ref) = @_;
  $a_options_ref ||= {};
  $b_options_ref ||= {};
  my ($a_handle, $b_handle) = create_handle_pair();
  return (
    AnyEvent::WebSocket::Connection->new(%$a_options_ref, handle => $a_handle),
    AnyEvent::WebSocket::Connection->new(%$b_options_ref, handle => $b_handle),
  );
}

sub create_connection_and_handle
{
  my ($a_options_ref) = @_;
  my ($a_handle, $b_handle) = create_handle_pair();
  return (
    AnyEvent::WebSocket::Connection->new(%$a_options_ref, handle => $a_handle),
    $b_handle
  );
}

1;
