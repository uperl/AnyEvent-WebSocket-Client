use lib 't/lib';
use Test2::Plugin::EV;
use Test2::Plugin::AnyEvent::Timeout;
use Test2::V0 -no_srand => 1;
use Test2::Tools::WebSocket::Server qw( start_echo );
use AnyEvent::WebSocket::Client;

my $uri = start_echo;

my $connection = AnyEvent::WebSocket::Client->new()->connect($uri)->recv;
ok $connection->masked, "Client Connection should set masked => true";

done_testing;
