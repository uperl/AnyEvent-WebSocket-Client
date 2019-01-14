use strict;
use warnings;
use Test2::V0 -no_srand => 1;
use File::Temp qw(tempdir);
use AnyEvent;
use AnyEvent::Socket qw(tcp_server);
use JSON qw(to_json from_json);
our $CV;

our $LAST_CLIENT;
our $LAST_SERVER;
our $t;

our $TEST_MSG_COUNT=3;
our $CONNECTION_COUNT=3;

# lazy hack to force skip in unsupported platforms
eval {
  
  my $dir = tempdir(CLEANUP=>1);
  my $socket="$dir/test.sock";

  use AnyEvent::WebSocket::Server;
  use AnyEvent::WebSocket::Client;
  use IO::Socket::UNIX;
  {
    my $server = IO::Socket::UNIX->new(
      Type => SOCK_STREAM(),
      Local => $socket,
      Listen => 1,
    ) or die "unsupported\n";
  }
};

our $SKIP_ALL=$@;
SKIP: {
 skip_all 'unsupported' if $SKIP_ALL;
  SKIP: {
    skip 'unsupported',45 if $SKIP_ALL;
   
    my $dir = tempdir(CLEANUP=>1);
    my $socket="$dir/test.sock";
  
   
    my $server = AnyEvent::WebSocket::Server->new();
    my $server_conn;
    my $tcp_server = tcp_server 'unix/', $socket, sub {
      my ($fh)=@_;
      $server->establish($fh)->cb(sub {
        $server_conn=eval { shift->recv };
   
        undef $t;
        $CV->send('client - connected');
   
        if($@) {
          return $CV->send("error: $@");
        }
   
        $server_conn->on(each_message => sub {
          my ($conn,$msg)=@_;
          $LAST_CLIENT=$msg->decoded_body;
          undef $t;
          $CV->send('client - ok');
        });
   
        $server_conn->on(finish=>sub {
          my ($conn)=@_;
          undef $t;
          $CV->send('client - close');
          $conn->close;
          undef $conn;
        });
      });
    };
   
    for(my $x=0;$x<$CONNECTION_COUNT;++$x) {
      my $client=AnyEvent::WebSocket::Client->new(unix_socket=>$socket);
      cmp_ok($client->unix_socket,'eq',$socket,'make sure the object has our socket connection: '.$x);
      my $client_conn;
     
      $client->connect("ws://localhost:123$x")->cb(sub {
        $client_conn=eval { shift->recv };
        if($@) {
            undef $t;
          return $CV->send("error, $@");
        }
     
        $client_conn->on(each_message=>sub {
          my ($conn,$msg)=@_;
          $LAST_SERVER=$msg->decoded_body;
          undef $t;
          $CV->send('server - ok');
        });
     
        $client_conn->on(finish=>sub {
          my ($conn);
          $conn->close;
          undef $conn;
        });
      });
      {
        my $res=next_cv();
        cmp_ok($res,'eq','client - connected','connection open check connection: '.$x);
      }
      for(my $id=0;$id<$TEST_MSG_COUNT;++$id) {
        {
          my $msg=to_json {testing=>$id};
          $server_conn->send($msg);
          my $res=next_cv();
          cmp_ok($res,'eq','server - ok','send data from server to client set: '.$id);
          cmp_ok($LAST_SERVER,'eq',$msg,'last message from the server should match our current message set: '.$id);
        }
        {
          my $msg=to_json {testing=>$id};
          $client_conn->send($msg);
          my $res=next_cv();
          cmp_ok($res,'eq','client - ok','send data from server to client set: '.$id);
          cmp_ok($LAST_CLIENT,'eq',$msg,'last message from the client should match our current message set: '.$id);
        }
      }
  
      {
        $client_conn->close;
        my $res=next_cv();
        diag $res;
        cmp_ok($res,'eq','client - close','Should have closed the client connection without error');
      }
    }
  };
  
  SKIP: {
    skip 'unsupported',45 if $SKIP_ALL;
   
    my $dir = tempdir(CLEANUP=>1);
    my $socket="$dir/test.sock";
  
    use AnyEvent::WebSocket::Client;
   
    my $server = AnyEvent::WebSocket::Server->new();
    my $server_conn;
    my $tcp_server = tcp_server 'unix/', $socket, sub {
      my ($fh)=@_;
      $server->establish($fh)->cb(sub {
        $server_conn=eval { shift->recv };
   
        undef $t;
        $CV->send('client - connected');
   
        if($@) {
          return $CV->send("error: $@");
        }
   
        $server_conn->on(each_message => sub {
          my ($conn,$msg)=@_;
          $LAST_CLIENT=$msg->decoded_body;
          undef $t;
          $CV->send('client - ok');
        });
   
        $server_conn->on(finish=>sub {
          my ($conn)=@_;
          undef $t;
          $CV->send('client - close');
          $conn->close;
          undef $conn;
        });
      });
    };
   
    for(my $x=0;$x<$CONNECTION_COUNT;++$x) {
      my $client=AnyEvent::WebSocket::Client->new();
      my $client_conn;
     
      $client->connect("ws://localhost:123$x",unix=>$socket)->cb(sub {
        $client_conn=eval { shift->recv };
        if($@) {
            undef $t;
          return $CV->send("error, $@");
        }
     
        $client_conn->on(each_message=>sub {
          my ($conn,$msg)=@_;
          $LAST_SERVER=$msg->decoded_body;
          undef $t;
          $CV->send('server - ok');
        });
     
        $client_conn->on(finish=>sub {
          my ($conn);
          $conn->close;
          undef $conn;
        });
      });
      {
        my $res=next_cv();
        cmp_ok($res,'eq','client - connected','connection open check connection: '.$x);
      }
      for(my $id=0;$id<$TEST_MSG_COUNT;++$id) {
        {
          my $msg=to_json {testing=>$id};
          $server_conn->send($msg);
          my $res=next_cv();
          cmp_ok($res,'eq','server - ok','send data from server to client set: '.$id);
          cmp_ok($LAST_SERVER,'eq',$msg,'last message from the server should match our current message set: '.$id);
        }
        {
          my $msg=to_json {testing=>$id};
          $client_conn->send($msg);
          my $res=next_cv();
          cmp_ok($res,'eq','client - ok','send data from server to client set: '.$id);
          cmp_ok($LAST_CLIENT,'eq',$msg,'last message from the client should match our current message set: '.$id);
        }
      }
  
      {
        $client_conn->close;
        my $res=next_cv();
        diag $res;
        cmp_ok($res,'eq','client - close','Should have closed the client connection without error');
      }
    }
  }
  
  SKIP: {
    skip 'unsupported',45 if $SKIP_ALL;
    skip 'ENV TEST_HOST and TEST_PORT not set' ,45 if !$ENV{TEST_HOST} || !$ENV{TEST_PORT};
   
    my ($host,$socket)=@ENV{qw(TEST_HOST TEST_PORT)};
   
    my $server = AnyEvent::WebSocket::Server->new();
    my $server_conn;
    my $tcp_server = tcp_server $host, $socket, sub {
      my ($fh)=@_;
      $server->establish($fh)->cb(sub {
        $server_conn=eval { shift->recv };
   
        undef $t;
        $CV->send('client - connected');
   
        if($@) {
          return $CV->send("error: $@");
        }
   
        $server_conn->on(each_message => sub {
          my ($conn,$msg)=@_;
          $LAST_CLIENT=$msg->decoded_body;
          undef $t;
          $CV->send('client - ok');
        });
   
        $server_conn->on(finish=>sub {
          my ($conn)=@_;
          undef $t;
          $CV->send('client - close');
          $conn->close;
          undef $conn;
        });
      });
    };
   
    for(my $x=0;$x<$CONNECTION_COUNT;++$x) {
      my $client=AnyEvent::WebSocket::Client->new();
      my $client_conn;
     
      $client->connect("ws://notlocalhost:123$x",host=>$host,port=>$socket)->cb(sub {
        $client_conn=eval { shift->recv };
        if($@) {
            undef $t;
          return $CV->send("error, $@");
        }
     
        $client_conn->on(each_message=>sub {
          my ($conn,$msg)=@_;
          $LAST_SERVER=$msg->decoded_body;
          undef $t;
          $CV->send('server - ok');
        });
     
        $client_conn->on(finish=>sub {
          my ($conn);
          $conn->close;
          undef $conn;
        });
      });
      {
        my $res=next_cv();
        cmp_ok($res,'eq','client - connected','connection open check connection: '.$x);
      }
      for(my $id=0;$id<$TEST_MSG_COUNT;++$id) {
        {
          my $msg=to_json {testing=>$id};
          $server_conn->send($msg);
          my $res=next_cv();
          cmp_ok($res,'eq','server - ok','send data from server to client set: '.$id);
          cmp_ok($LAST_SERVER,'eq',$msg,'last message from the server should match our current message set: '.$id);
        }
        {
          my $msg=to_json {testing=>$id};
          $client_conn->send($msg);
          my $res=next_cv();
          cmp_ok($res,'eq','client - ok','send data from server to client set: '.$id);
          cmp_ok($LAST_CLIENT,'eq',$msg,'last message from the client should match our current message set: '.$id);
        }
      }
  
      {
        $client_conn->close;
        my $res=next_cv();
        diag $res;
        cmp_ok($res,'eq','client - close','Should have closed the client connection without error');
      }
    }
  }
}
sub next_cv {
  ($LAST_SERVER,$LAST_CLIENT)=(undef,undef);
  $CV=AnyEvent->condvar;
  $t=AnyEvent->timer(after=>10,cb=>sub {
    $CV->send('unit test timed out');
  });
  return $CV->recv;
}

diag $@ if $@;
done_testing;
