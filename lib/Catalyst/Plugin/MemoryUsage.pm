package Catalyst::Plugin::MemoryUsage;
#ABSTRACT: Profile memory usage of requests

use strict;
use warnings;

use namespace::autoclean;
use Moose::Role;
use MRO::Compat;

use Memory::Usage;

use Devel::CheckOS;

our @SUPPORTED_OSES = qw/ Linux NetBSD /;

our $os_not_supported = Devel::CheckOS::os_isnt( @SUPPORTED_OSES );

if ( $os_not_supported ) {
    warn "OS not supported by Catalyst::Plugin::MemoryUsage\n",
         "\tStats will not be collected\n";
}

=head1 SYNOPSIS

In YourApp.pm:

    package YourApp;

    use Catalyst qw/
        MemoryUsage
    /;

In a Controller class:

    sub foo :Path( '/foo' ) {
         # ...
         
         something_big_and_scary();
         
         $c->memory_usage->record( 'finished running iffy code' );
         
         # ...
    }
    
=head1 DESCRIPTION

C<Catalyst::Plugin::MemoryUsage> adds a memory usage profile to your debugging
log, which looks like this:   

    [debug] memory usage of request
    time    vsz (  diff)    rss (  diff) shared (  diff)   code (  diff)   data (  diff)
        0  45304 ( 45304)  38640 ( 38640)   3448 (  3448)   1112 (  1112)  35168 ( 35168) preparing for the request
        0  45304 (     0)  38640 (     0)   3448 (     0)   1112 (     0)  35168 (     0) after Galuga::Controller::Root : _BEGIN
        0  45304 (     0)  38640 (     0)   3448 (     0)   1112 (     0)  35168 (     0) after Galuga::Controller::Root : _AUTO
        0  46004 (   700)  39268 (   628)   3456 (     8)   1112 (     0)  35868 (   700) finished running iffy code
        0  46004 (     0)  39268 (     0)   3456 (     0)   1112 (     0)  35868 (     0) after Galuga::Controller::Entry : entry/index
        0  46004 (     0)  39268 (     0)   3456 (     0)   1112 (     0)  35868 (     0) after Galuga::Controller::Root : _ACTION
        1  47592 (  1588)  40860 (  1592)   3468 (    12)   1112 (     0)  37456 (  1588) after Galuga::View::Mason : Galuga::View::Mason->process
        1  47592 (     0)  40860 (     0)   3468 (     0)   1112 (     0)  37456 (     0) after Galuga::Controller::Root : end
        1  47592 (     0)  40860 (     0)   3468 (     0)   1112 (     0)  37456 (     0) after Galuga::Controller::Root : _END
        1  47592 (     0)  40860 (     0)   3468 (     0)   1112 (     0)  37456 (     0) after Galuga::Controller::Root : _DISPATCH

=head1 METHODS

=head2 C<memory_usage()>

Returns the L<Memory::Usage> object available to the context.

To record more measure points for the memory profiling, use the C<record()>
method of that object:

    sub foo :Path {
        my ( $self, $c) = @_;

        ...

        big_stuff();

        $c->memory_usage->record( "done with big_stuff()" );

        ...
    }

=cut

has memory_usage => (
    is => 'rw',
    default => sub { Memory::Usage->new },
);

=head2 C<memory_usage_profiling( $enable )>

Enable or disable automatic memory profiling. When enabled, 
memory snapshots are taken after each action and automatically
reported in the logs as shown in the DESCRIPTION.  If it's disabled,
the C<memory_usage> method is still available but no data collection
or reporting is done automatically.

Without an argument, returns true if profiling is enabled, false otherwise.

By default, profiling will be enabled if the application is running 
in debugging mode (and if the OS is supported by
C<Catalyst::Plugin::MemoryUsage>, natch), and disabled
otherwise.

=cut


has memory_usage_profiling => (
    is      => 'rw',
    default => sub { !$os_not_supported and (shift)->debug },
    lazy    => 1,
);

=head2 C<reset_memory_usage()>

Discards the current C<Memory::Usage> object, along with its recorded data,
and replaces it by a shiny new one.

=cut

sub reset_memory_usage {
    my $self = shift;

    $self->memory_usage( Memory::Usage->new );
}

    after execute => sub {
        my $c = shift;

        return unless $c->memory_usage_profiling;

        $c->memory_usage->record( "after " . join " : ", @_ );
    };

    around prepare => sub {
        my $orig = shift;
        my $self = shift;

        my $c = $self->$orig(@_);

        if ( $c->memory_usage_profiling ) {
            $c->reset_memory_usage;
            $c->memory_usage->record('preparing for the request');
        }

        return $c;
    };

    before finalize => sub {
        my $c = shift;

        return unless $c->memory_usage_profiling;

        $c->log->debug( 'memory usage of request', $c->memory_usage->report );
    };


1;

=head1 BUGS AND LIMITATIONS

C<Memory::Usage>, which is the module C<Catalyst::Plugin::MemoryUsage> relies
on to get its statistics, only work for Linux-based platforms. Consequently,
for the time being C<Catalyst::Plugin::MemoryUsage> only work on Linux and
NetBSD. This being said, patches are most welcome. :-)

=head1 SEE ALSO

L<Memory::Usage>

=cut


