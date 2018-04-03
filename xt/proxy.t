use strict;
use warnings;
use Test::More;
use AnyEvent;
use AnyEvent::WebSocket::Client;
use Try::Tiny;

sub get_env {
    my ($env_name, $desc) = @_;
    my $val = $ENV{$env_name};
    if(!defined($val) || $val eq "") {
        plan skip_all => "Set $env_name environment variable to $desc to enable this test.";
    }
    return $val;
}

sub test_client_at {
    my ($client, $echo_url, $exp_conn_success) = @_;
    my ($conn, $err) = try {
        (scalar($client->connect($echo_url)->recv), undef);
    }catch {
        (undef, $_[0])
    };
    if(!$exp_conn_success) {
        is $conn, undef;
        like $err, qr/unable to connect/i;
        return;
    }
    isnt $conn, undef;
    is $err, undef;
    my $res_cv = AnyEvent->condvar;
    $conn->on(next_message => sub {
        $res_cv->send($_[1]->decoded_body);
    });
    $conn->send("foo bar");
    my $got = $res_cv->recv;
    is $got, "foo bar", $echo_url;
}

sub test_client {
    my ($client, $exp_conn_success) = @_;
    test_client_at($client, "ws://echo.websocket.org/", $exp_conn_success);
    test_client_at($client, "wss://echo.websocket.org/", $exp_conn_success);
}


my $PROXY_URL = get_env("PERL_AE_WS_C_TEST_PROXY_URL", "the proxy URL");
my $PROXY_ON =  get_env("PERL_AE_WS_C_TEST_PROXY_ON", "0 (if the proxy is down) or 1 (if the proxy is up)");

foreach my $n (qw(ws http wss https)) {
    my $e = "${n}_proxy";
    delete $ENV{lc($e)};
    delete $ENV{uc($e)};
}

subtest "no proxy", sub {
    test_client(AnyEvent::WebSocket::Client->new(), 1);
};

subtest "ws and wss proxy", sub {
    local $ENV{ws_proxy} = $PROXY_URL;
    local $ENV{wss_proxy} = $PROXY_URL;
    test_client(AnyEvent::WebSocket::Client->new(env_proxy => 1), $PROXY_ON);
};

subtest "http and https proxy", sub {
    local $ENV{http_proxy} = $PROXY_URL;
    local $ENV{https_proxy} = $PROXY_URL;
    test_client(AnyEvent::WebSocket::Client->new(env_proxy => 1), $PROXY_ON);
};

done_testing;
