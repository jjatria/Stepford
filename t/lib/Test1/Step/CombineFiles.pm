package Test1::Step::CombineFiles;

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

has a1_file_updated => (
    traits   => ['StepDependency'],
    is       => 'ro',
    isa      => Path,
    required => 1,
);

has a2_file_updated => (
    traits   => ['StepDependency'],
    is       => 'ro',
    isa      => Path,
    required => 1,
);

has combined_file => (
    traits  => ['StepProduction'],
    is      => 'ro',
    isa     => Path,
    lazy    => 1,
    default => sub { $_[0]->tempdir->child('combined') },
);

## no critic (Variables::ProhibitPackageVars)
our $RunCount = 0;

sub run {
    my $self = shift;

    $self->combined_file->spew(
        [
            map { $_->slurp } $self->a1_file_updated,
            $self->a2_file_updated
        ]
    );
}

after run => sub { $RunCount++ };

sub run_count { $RunCount }

__PACKAGE__->meta->make_immutable;

1;
