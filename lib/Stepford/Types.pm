package Stepford::Types;

use strict;
use warnings;

our $VERSION = '0.004002';

use Type::Library -base;
use Type::Utils qw( extends );

extends qw(
    Types::Standard
    Types::Path::Tiny
    Types::Common::String
    Types::Common::Numeric
    Stepford::Types::Internal
);

1;

# ABSTRACT: Type library used in Stepford classes/roles
