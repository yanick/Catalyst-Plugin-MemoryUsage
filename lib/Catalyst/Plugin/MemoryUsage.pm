package Catalyst::Plugin::MemoryUsage;
#ABSTRACT: Profile memory usage of requests

use strict;
use warnings;

use namespace::autoclean;
use Moose::Role;
use MRO::Compat;

use Memory::Usage;

use Devel::CheckOS;
use Text::SimpleTable;
use Number::Bytes::Human qw/ format_bytes /;
use List::Util qw/ max /;

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
 .--------------------------------------------------+------+------+------+------+------+------+------+------+------+------.
 |                                                  | vsz  | del- | rss  | del- | sha- | del- | code | del- | data | del- |
 |                                                  |      | ta   |      | ta   | red  | ta   |      | ta   |      | ta   |
 +--------------------------------------------------+------+------+------+------+------+------+------+------+------+------+
 | preparing for the request                        | 28M  |      | 22M  |      | 2.2M |      | 1.1M |      | 20M  |      |
 | after TestApp::Controller::Root : root/_BEGIN    | 28M  |      | 22M  |      | 2.2M |      | 1.1M |      | 20M  |      |
 | after TestApp::Controller::Root : root/_AUTO     | 28M  |      | 22M  |      | 2.2M |      | 1.1M |      | 20M  |      |
 | in the middle of index                           | 28M  |      | 22M  |      | 2.2M |      | 1.1M |      | 20M  |      |
 | after TestApp::Controller::Root : root/index     | 28M  |      | 22M  |      | 2.2M |      | 1.1M |      | 20M  |      |
 | after TestApp::Controller::Root : root/_ACTION   | 28M  |      | 22M  |      | 2.2M |      | 1.1M |      | 20M  |      |
 | after TestApp::Controller::Root : root/_END      | 28M  |      | 22M  |      | 2.2M |      | 1.1M |      | 20M  |      |
 | after TestApp::Controller::Root : root/_DISPATCH | 28M  |      | 22M  |      | 2.2M |      | 1.1M |      | 20M  |      |
 '--------------------------------------------------+------+------+------+------+------+------+------+------+------+------'  

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

=head2 C<reset_memory_usage()>

Discards the current C<Memory::Usage> object, along with its recorded data,
and replaces it by a shiny new one.

=cut

sub reset_memory_usage {
    my $self = shift;

    $self->memory_usage( Memory::Usage->new );
}

sub memory_usage_report {
    my $self = shift;

    my $title_width = max 10,
        map { length $_->[1] } @{ $self->memory_usage->state };

    my $table = Text::SimpleTable->new( 
        [$title_width, ''],
        [4, 'vsz'],
        [4, 'delta'],
        [4, 'rss'],
        [4, 'delta'],
        [4, 'shared'],
        [4, 'delta'],
        [4, 'code'],
        [4, 'delta'],
        [4, 'data'],
        [4, 'delta'],
    );

    my @previous;

    for my $s ( @{ $self->memory_usage->state } ) {
        my ( $time, $msg, @sizes ) = @$s;

        my @data = map { $_ ? format_bytes( 1024 * $_) : '' } map { 
            ( $sizes[$_], @previous ? $sizes[$_] - $previous[$_]  : 0 )
        } 0..4;
        @previous = @sizes;

        $table->row( $msg, @data );
    }

    return $table->draw;
}

unless ( $os_not_supported ) {

after execute => sub {
    my $c = shift;

    return if $os_not_supported;

    $c->memory_usage->record( "after " . join " : ", @_ );
};

around prepare => sub {
    my $orig = shift;
    my $self = shift;

    my $c = $self->$orig(@_);

    $c->reset_memory_usage;
    $c->memory_usage->record('preparing for the request');

    return $c;
};

before finalize => sub {
    my $c = shift;

    $c->log->debug( 'memory usage of request'. "\n". $c->memory_usage_report );
};

}

1;

=head1 BUGS AND LIMITATIONS

C<Memory::Usage>, which is the module C<Catalyst::Plugin::MemoryUsage> relies
on to get its statistics, only work for Linux-based platforms. Consequently,
for the time being C<Catalyst::Plugin::MemoryUsage> only work on Linux and
NetBSD. This being said, patches are most welcome. :-)

=head1 SEE ALSO

L<Memory::Usage>

=cut


