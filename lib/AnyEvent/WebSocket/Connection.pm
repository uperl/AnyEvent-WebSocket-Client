package AnyEvent::WebSocket::Connection;

use strict;
use warnings;
use v5.10;
use Moo;
use warnings NONFATAL => 'all';
use Protocol::WebSocket::Frame;

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

has _handle => (
  is       => 'ro',
  required => 1,
);

foreach my $type (qw( each next finish ))
{
  has "_${type}_cb" => (
    is       => 'ro',
    init_arg => undef,
    default  => sub { [] },
  );
}

sub BUILD
{
  my $self = shift;

  my $finish = sub {
    $_->() for @{ $self->_finish_cb };
  };
  $self->_handle->on_error($finish);
  $self->_handle->on_eof($finish);

  my $frame = Protocol::WebSocket::Frame->new;
  
  $self->_handle->on_read(sub {
    $self->_handle->push_read(sub {
      $frame->append($_[0]{rbuf});
      if(my $message = $frame->next)
      {
        $_->($message) for @{ $self->_next_cb };
        @{ $self->_next_cb } = ();
        $_->($message) for @{ $self->_each_cb };
      }
    });
  });
}

=head1 METHODS

=head2 $connection-E<gt>send($message)

=cut

sub send
{
  my $self = shift;
  $self->_handle->push_write(
    Protocol::WebSocket::Frame->new(shift)->to_bytes
  );
  $self;
}

=head2 $connection-E<gt>on_each_message($cb)

=cut

sub on_each_message
{
  my($self, $cb) = @_;
  push @{ $self->_each_cb }, $cb;
  $self;
}

=head2 $connection-E<gt>on_next_message($cb)

=cut

sub on_next_message
{
  my($self, $cb) = @_;
  push @{ $self->_next_cb }, $cb;
  $self;
}

=head2 $connection-E<gt>on_finish($cb)

=cut

sub on_finish
{
  my($self, $cb) = @_;
  push @{ $self->_finish_cb }, $cb;
  $self;
}

1;

=head1 SEE ALSO

L<AnyEvent::WebSocket::Client>, L<AnyEvent>

=cut
