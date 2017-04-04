package Test1::Step::CreateA2;

use strict;
use warnings;
use namespace::autoclean;

use Stepford::Types qw( Path );

use Moose;

with 'Stepford::Role::Step::FileGenerator';

has tempdir => (
    is       => 'ro',
    isa      => Path,
    required => 1,
);

has a2_file => (
    traits  => [qw( StepProduction )],
    is      => 'ro',
    isa     => Path,
    lazy    => 1,
    default => sub { $_[0]->tempdir->child('a2') },
);

## no critic (Variables::ProhibitPackageVars)
our $RunCount = 0;

sub run {
    my $self = shift;

    return if -f $self->a2_file;

    $self->a2_file->touch;
}

after run => sub { $RunCount++ };

sub run_count { $RunCount }

__PACKAGE__->meta->make_immutable;

1;
