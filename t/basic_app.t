
use strict;

use Test::More;    # last test to print

use lib 't/lib';

use Test::WWW::Mechanize::Catalyst;
my $mech = Test::WWW::Mechanize::Catalyst->new(catalyst_app => 'TestApp');

$mech->get_ok('/index');

my ( $profile ) = grep { /memory usage/ } @{ $MyLog::mylog->{debug} };

ok $profile, "profile is reported";

like $profile, qr/in the middle of index/, '$c->memory_usage->record() output';

note $profile;

done_testing();

