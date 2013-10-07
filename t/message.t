use strict;
use warnings;
use Test::More tests => 5;
use AnyEvent::WebSocket::Message;

my %ops = qw(
  text   1
  binary 2
  close  8
  ping   9
  pong   10
);

my @methods = map { "is_$_" } keys %ops;

while(my($type, $opcode) = each %ops)
{
  subtest $type => sub {
    plan tests => 8;
    my $message = AnyEvent::WebSocket::Message->new(body => 'body', opcode => $opcode);
    is $message->body, 'body', 'message.body = body';
    is $message->opcode, $opcode, "message.opcode = $opcode";
    isa_ok $message, 'AnyEvent::WebSocket::Message';
    foreach my $method (@methods)
    {
      next if $method eq "is_$type";
      ok !$message->$method, "\$message->$method is false";
    }
    
    my $method = "is_$type";
    ok $message->$method, "\$message->$method is true";
  };
}
