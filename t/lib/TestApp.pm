
package MyLog;

$MyLog::mylog = bless {}, 'MyLog';

sub new {
    return $mylog;
}

sub can {
    0;
}

sub error {
    shift;
    push @{ $MyLog::mylog->{error} }, "@_";
}

sub debug {
    shift;
    push @{ $MyLog::mylog->{debug} }, "@_";
}


package TestApp;

use strict;
use warnings;

use Catalyst qw/ MemoryUsage /;

__PACKAGE__->setup;

sub log {
    return MyLog->new;
}


1;
