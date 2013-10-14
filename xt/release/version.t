use strict;
use warnings;
use Test::More;
use FindBin ();
BEGIN { plan skip_all => "test requires Test::Version 1.001001" unless eval q{ use Test::Version 1.001001 qw( version_all_ok ), { is_strict => 1, has_version => 1 }; 1 } }
BEGIN { plan skip_all => "test requires Path::Class" unless eval q{ use Path::Class qw( file dir ); 1 } }

plan skip_all => "test not built yet (run dzil test)"
  unless -e dir( $FindBin::Bin)->parent->parent->file('Makefile.PL')
  ||     -e dir( $FindBin::Bin)->parent->parent->file('Build.PL');

version_all_ok();
done_testing;
