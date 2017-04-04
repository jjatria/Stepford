package Stepford::Types::Internal;

use strict;
use warnings;

our $VERSION = '0.004002';

use Type::Library
    -base,
    -declare => qw(
    ArrayOfClassPrefixes
    ArrayOfDependencies
    ArrayOfFiles
    ArrayOfSteps
    Logger
    PossibleClassName
    Step
    Graph
    MemoryStats
);

use Type::Utils qw(
    as class_type coerce declare duck_type extends from inline_as via where
);
use Types::Common::String qw( NonEmptyStr );
use Types::Standard qw( Any ArrayRef Defined Str );
use Types::Path::Tiny qw( Path );

use namespace::clean;

class_type 'Graph',       { class => 'Stepford::Graph' };
class_type 'MemoryStats', { class => 'Memory::Stats' };

declare 'PossibleClassName', as Str, inline_as {
    ## no critic (Subroutines::ProtectPrivateSubs)
    $_[0]->parent->_inline_check( $_[1] ) . ' && '
        . $_[1]
        . ' =~ /^\\p{L}\\w*(?:::\\w+)*$/';
};

declare 'ArrayOfClassPrefixes', as ArrayRef [PossibleClassName], inline_as {
    ## no critic (Subroutines::ProtectPrivateSubs)
    $_[0]->parent->_inline_check( $_[1] ) . " && \@{ $_[1] } >= 1";
};

coerce 'ArrayOfClassPrefixes', from PossibleClassName, via { [$_] };

declare 'ArrayOfDependencies', as ArrayRef [NonEmptyStr];

coerce 'ArrayOfDependencies', from NonEmptyStr, via { [$_] };

declare 'ArrayOfFiles', as ArrayRef [Path], inline_as {
    ## no critic (Subroutines::ProtectPrivateSubs)
    $_[0]->parent->_inline_check( $_[1] ) . " && \@{ $_[1] } >= 1";
};

coerce 'ArrayOfFiles', from Path, via { [$_] };

duck_type 'Logger', [qw( debug info notice warning error )];

declare 'Step', as Any, where { $_->does('Stepford::Role::Step') };

declare 'ArrayOfSteps', as ArrayRef [Step];

coerce 'ArrayOfSteps', from Step, via { [$_] };

1;

# ABSTRACT: Internal type definitions for Stepford
