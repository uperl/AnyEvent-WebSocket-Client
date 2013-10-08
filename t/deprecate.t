use strict;
use warnings;
use Test::More;
BEGIN { eval q{ use EV } }
BEGIN { plan skip_all => 'test requires Test::Warn' unless eval q{ use Test::Warn; 1 } }
use AnyEvent::WebSocket::Client;
use AnyEvent::Socket qw( tcp_server );
use Protocol::WebSocket::Handshake::Server;
use Protocol::WebSocket::Frame;
use FindBin ();
use lib $FindBin::Bin;
use testlib::Server;

plan tests => 4;

testlib::Server->set_timeout;

my $uri = testlib::Server->start_echo;

my $connection = AnyEvent::WebSocket::Client->new->connect($uri)->recv;
isa_ok $connection, 'AnyEvent::WebSocket::Connection';

warning_like { $connection->on_next_message(sub { }) } qr{on_next_message is deprecated}, "deprecation warning for on_next_message";
warning_like { $connection->on_each_message(sub { }) } qr{on_each_message is deprecated}, "deprecation warning for on_each_message";
warning_like { $connection->on_finish(sub { }) } qr{on_finish is deprecated}, "deprecation warning for on_finish";
