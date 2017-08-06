use utf8;
use lib 't/lib';
use Test2::Plugin::EV;
use Test2::Plugin::AnyEvent::Timeout;
use Test2::V0 -no_srand => 1;
use Test2::Tools::WebSocket::Connection qw( create_connection_pair );
use AnyEvent::WebSocket::Connection;

subtest 'ascii' => sub {

  my($a, $b) = create_connection_pair;

  my $cv = AnyEvent->condvar;
  my $reason;
  my $code;

  $b->on(finish => sub {
    my($con) = @_;
    $code   = $con->close_code;
    $reason = $con->close_reason;
    $cv->send;
  });

  $a->close(1009 => 'anything');

  $cv->recv;

  is $code,   1009,       'code is available in finish callback';
  is $reason, 'anything', 'reason is available in finish callback';

  is(
    $b,
    object {
      call close_code   => 1009;
      call close_reason => 'anything';
    },
    'connection has finish code and reason',
  );
};

subtest 'unicode' => sub {

  my($a, $b) = create_connection_pair;

  my $cv = AnyEvent->condvar;
  my $reason;
  my $code;

  $b->on(finish => sub {
    my($con) = @_;
    $code   = $con->close_code;
    $reason = $con->close_reason;
    $cv->send;
  });

  $a->close(1009 => 'ＵＴＦ８ ＷＩＤＥ ＣＨＡＲＡＣＴＥＲＳ');

  $cv->recv;

  is $code,   1009,                                     'code is available in finish callback';
  is $reason, 'ＵＴＦ８ ＷＩＤＥ ＣＨＡＲＡＣＴＥＲＳ', 'reason is available in finish callback';

  is(
    $b,
    object {
      call close_code   => 1009;
      call close_reason => 'ＵＴＦ８ ＷＩＤＥ ＣＨＡＲＡＣＴＥＲＳ';
    },
    'connection has finish code and reason',
  );

};

done_testing;
