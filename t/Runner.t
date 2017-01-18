## no critic (Moose::RequireCleanNamespace, Moose::RequireMakeImmutable, Modules::ProhibitMultiplePackages)
use strict;
use warnings;
use autodie;

use lib 't/lib';

use List::AllUtils qw( first );
use Log::Dispatch;
use Log::Dispatch::Array;
use Path::Class qw( dir tempdir );
use Stepford::Runner;
use Time::HiRes 1.9726 qw( stat time );

use Test::Differences;
use Test::Fatal;
use Test::More;

my $tempdir = tempdir( CLEANUP => 1 );

{
    my @messages;
    my $logger = Log::Dispatch->new(
        outputs => [
            [
                'Array',
                name      => 'array',
                array     => \@messages,
                min_level => 'debug',
            ]
        ]
    );

    require Test1::Step::CombineFiles;

    my $runner = Stepford::Runner->new(
        step_namespaces => 'Test1::Step',
        logger          => $logger,
    );

    _test_plan(
        $runner,
        'Test1::Step',
        ['CombineFiles'],
        {
            'CombineFiles' => {
                'UpdateFiles' => {
                    'CreateA1' => undef,
                    'CreateA2' => undef,
                },
            },
        },
        'runner comes up with the right plan for simple steps'
    );

    @messages = ();

    $runner->run(
        final_steps => 'Test1::Step::CombineFiles',
        config      => { tempdir => $tempdir },
    );

    my @dep_messages = grep {
               $_->{level} eq 'debug'
            && $_->{message} =~ /^Dependency \w+ for/
    } @messages;

    is(
        scalar @dep_messages,
        4,
        'logged four dependency resolution messages'
    );

    my $graph_message = first { $_->{message} =~ /Graph for/ } @messages;

    is(
        $graph_message->{message},
        <<'EOF',
Graph for Test1::Step::CombineFiles:
Stepford::FinalStep
    Test1::Step::CombineFiles
        Test1::Step::UpdateFiles
            Test1::Step::CreateA1
            Test1::Step::CreateA2
EOF
        'logged plan when ->run was called'
    );

    is(
        $graph_message->{level},
        'debug',
        'log level for graph description is debug'
    );

    my @object_constructor_messages
        = grep { $_->{level} eq 'debug' && $_->{message} =~ /\Q->new/ }
        @messages;
    is(
        scalar @object_constructor_messages,
        5,
        'logged five object construction messages'
    );

    is(
        $object_constructor_messages[0]{message},
        'Test1::Step::CreateA1->new',
        'logged a message indicating that a step was being created'
    );

    is(
        $object_constructor_messages[0]{level},
        'debug',
        'log level for object creation is debug'
    );

    for my $file ( map { $tempdir->file($_) } qw( a1 a2 combined ) ) {
        ok( -f $file, $file->basename . ' file exists' );
    }

    @messages = ();

    $runner->run(
        final_steps => 'Test1::Step::CombineFiles',
        config      => { tempdir => $tempdir },
    );

    ok(
        (
            grep {
                $_->{message}
                    =~ /^\QLast run time for Test1::Step::CombineFiles is \E.+\QPrevious steps last run time is/
            } @messages
        ),
        'logged a message when skipping a step'
    );

    is(
        $messages[-1]{level},
        'info',
        'log level for skipping a step is info'
    );

    my %expect_run = (
        CreateA1     => 1,
        CreateA2     => 1,
        UpdateFiles  => 1,
        CombineFiles => 1,
    );

    for my $suffix ( sort keys %expect_run ) {
        my $class = 'Test1::Step::' . $suffix;

        is(
            $class->run_count,
            $expect_run{$suffix},
            "$class->run was called the expected number of times - skipped when up to date"
        );
    }
}

{
    package Test2::Step::A;

    use Moose;
    with 'Stepford::Role::Step';

    has thing_a => (
        traits => ['StepProduction'],
        is     => 'ro',
    );

    sub run           { }
    sub last_run_time { }
}

{
    package Test2::Step::B;

    use Moose;
    with 'Stepford::Role::Step';

    has thing_a => (
        traits   => ['StepDependency'],
        is       => 'ro',
        required => 1,
    );

    has thing_b => (
        traits => ['StepProduction'],
        is     => 'ro',
    );

    sub run           { }
    sub last_run_time { }
}

{
    package Test2::Step::C;

    use Moose;
    with 'Stepford::Role::Step';

    has thing_b => (
        traits   => ['StepDependency'],
        is       => 'ro',
        required => 1,
    );

    has thing_c => (
        traits => ['StepProduction'],
        is     => 'ro',
    );

    sub run           { }
    sub last_run_time { }
}

{
    package Test2::Step::D;

    use Moose;
    with 'Stepford::Role::Step';

    has thing_b => (
        traits   => ['StepDependency'],
        is       => 'ro',
        required => 1,
    );

    has thing_c => (
        traits   => ['StepDependency'],
        is       => 'ro',
        required => 1,
    );

    has thing_d => (
        traits => ['StepProduction'],
        is     => 'ro',
    );

    sub run           { }
    sub last_run_time { }
}

{
    my $runner = Stepford::Runner->new(
        step_namespaces => 'Test2::Step',
    );

    _test_plan(
        $runner,
        'Test2::Step',
        'D',
        {
            D => {
                B => { A => undef },
                C => { B => { A => undef } },
            }
        },
        'repeated steps correctly show up in plan'
    );
}

{
    package Test3::Step::A;

    use Moose;
    with 'Stepford::Role::Step';

    has thing_a => (
        traits => ['StepProduction'],
        is     => 'ro',
    );

    has thing_b => (
        traits => ['StepDependency'],
        is     => 'ro',
    );

    sub run           { }
    sub last_run_time { }
}

{
    package Test3::Step::B;

    use Moose;
    with 'Stepford::Role::Step';

    has thing_a => (
        traits   => ['StepDependency'],
        is       => 'ro',
        required => 1,
    );

    has thing_b => (
        traits => ['StepProduction'],
        is     => 'ro',
    );

    sub run           { }
    sub last_run_time { }
}

{
    my $e = exception {
        Stepford::Runner->new(
            step_namespaces => 'Test3::Step',
            )->run(
            final_steps => 'Test3::Step::B',
            );
    };

    like(
        $e,
        qr/cyclic/,
        'cyclical dependencies cause the Planner constructor to die'
    );
}

{
    package Test4::Step::A;

    use Moose;
    with 'Stepford::Role::Step';

    has thing_a => (
        traits => ['StepProduction'],
        is     => 'ro',
    );

    has thing_b => (
        traits => ['StepDependency'],
        is     => 'ro',
    );

    sub run           { }
    sub last_run_time { }
}

{
    my $e = exception {
        Stepford::Runner->new(
            step_namespaces => 'Test4::Step',
            )->run(
            final_steps => 'Test4::Step::A',
            );
    };

    like(
        $e,
        qr/
              \QCannot resolve a dependency for Test4::Step::A. \E
              \QThere is no step that produces the thing_b attribute.\E
          /x,
        'unresolved dependencies cause the runner constructor to die'
    );
}

{
    package Test5::Step::A;

    use Moose;
    with 'Stepford::Role::Step';

    has thing_a => (
        traits => [qw( StepDependency StepProduction )],
        is     => 'ro',
    );

    sub run           { }
    sub last_run_time { }
}

{
    my $e = exception {
        Stepford::Runner->new(
            step_namespaces => 'Test5::Step',
            )->run(
            final_steps => 'Test5::Step::A',
            );
    };

    like(
        $e,
        qr/\QA dependency (thing_a) for Test5::Step::A resolved to the same step/,
        'cannot have an attribute that is both a dependency and production'
    );
}

{
    package Test6::Step::A1;

    use Moose;
    with 'Stepford::Role::Step';

    has thing_a => (
        traits => ['StepProduction'],
        is     => 'ro',
    );

    sub run           { }
    sub last_run_time { }
}

{
    package Test6::Step::A2;

    use Moose;
    with 'Stepford::Role::Step';

    has thing_a => (
        traits => ['StepProduction'],
        is     => 'ro',
    );

    sub run           { }
    sub last_run_time { }
}

{
    my $builder = Stepford::Runner->new(
        step_namespaces => 'Test6::Step',
    )->_make_root_graph_builder( ['Test6::Step::A2'], {} );

    ## no critic (Subroutines::ProtectPrivateSubs)
    is(
        $builder->_production_map->{thing_a},
        'Test6::Step::A1',
        'when two steps have the same production, choose the one that sorts first'
    );
}

{
    package Test7::Step::A;

    use Stepford::Types qw( File );

    use Moose;
    with 'Stepford::Role::Step::FileGenerator';

    has content => (
        is      => 'ro',
        default => 'default content',
    );

    has file => (
        traits  => ['StepProduction'],
        is      => 'ro',
        isa     => File,
        default => sub { $tempdir->file('test7-step-a') },
    );

    sub run {
        $_[0]->file->spew( $_[0]->content );
    }

    sub last_run_time { }
}

{
    my $runner = Stepford::Runner->new(
        step_namespaces => 'Test7::Step',
    );

    $runner->run(
        final_steps => 'Test7::Step::A',
        config      => {
            content => 'new content',
            ignored => 42,
        },
    );

    is(
        scalar $tempdir->file('test7-step-a')->slurp,
        'new content',
        'config passed to $runner->run is passed to step constructor'
    );
}

{
    package Test8::Step::ForShared::A;

    use Moose;
    with 'Stepford::Role::Step';

    has for_shared_a => (
        traits => ['StepProduction'],
        is     => 'ro',
    );

    sub run           { }
    sub last_run_time { }
}

{
    package Test8::Step::ForShared::B;

    use Moose;
    with 'Stepford::Role::Step';

    has for_shared_b => (
        traits => ['StepProduction'],
        is     => 'ro',
    );

    sub run           { }
    sub last_run_time { }
}

{
    package Test8::Step::Shared;

    use Moose;
    with 'Stepford::Role::Step';

    has for_shared_a => (
        traits => ['StepDependency'],
        is     => 'ro',
    );

    has for_shared_b => (
        traits => ['StepDependency'],
        is     => 'ro',
    );

    has shared => (
        traits => ['StepProduction'],
        is     => 'ro',
    );

    sub run           { }
    sub last_run_time { }
}

{
    package Test8::Step::ForFinal1::A;

    use Moose;
    with 'Stepford::Role::Step';

    has shared => (
        traits => ['StepDependency'],
        is     => 'ro',
    );

    has for_final1_a => (
        traits => ['StepProduction'],
        is     => 'ro',
    );

    sub run           { }
    sub last_run_time { }
}

{
    package Test8::Step::ForFinal2::A;

    use Moose;
    with 'Stepford::Role::Step';

    has shared => (
        traits => ['StepDependency'],
        is     => 'ro',
    );

    has for_final2_a => (
        traits => ['StepProduction'],
        is     => 'ro',
    );

    sub run           { }
    sub last_run_time { }
}

{
    package Test8::Step::ForFinal2::B;

    use Moose;
    with 'Stepford::Role::Step';

    has for_final2_a => (
        traits => ['StepDependency'],
        is     => 'ro',
    );

    has for_final2_b => (
        traits => ['StepProduction'],
        is     => 'ro',
    );

    sub run           { }
    sub last_run_time { }
}

{
    package Test8::Step::Final1;

    use Moose;
    with 'Stepford::Role::Step';

    has for_final1_a => (
        traits => ['StepDependency'],
        is     => 'ro',
    );

    sub run           { }
    sub last_run_time { }
}

{
    package Test8::Step::Final2;

    use Moose;
    with 'Stepford::Role::Step';

    has for_final2_b => (
        traits => ['StepDependency'],
        is     => 'ro',
    );

    sub run           { }
    sub last_run_time { }
}

{
    my $runner = Stepford::Runner->new(
        step_namespaces => 'Test8::Step',
    );

    _test_plan(
        $runner,
        'Test8::Step',
        [ 'Final1', 'Final2' ],
        {
            Final1 => {
                'ForFinal1::A' => => {
                    Shared => {
                        'ForShared::A' => undef,
                        'ForShared::B' => undef,
                    },
                },
            },
            Final2 => {
                'ForFinal2::B' => {
                    'ForFinal2::A' => {
                        Shared => {
                            'ForShared::A' => undef,
                            'ForShared::B' => undef,
                        },
                    },
                },
            },
        },
        'runner comes up with an optimized plan for multiple final steps'
    );
}

{
    package Test9::Step::A;

    use Moose;

    has thing_a => (
        traits => [qw( StepDependency StepProduction )],
        is     => 'ro',
    );

    sub run           { }
    sub last_run_time { }
}

{
    my $e = exception {
        Stepford::Runner->new(
            step_namespaces => 'Test9::Step',
            )->run(
            final_steps => 'Test9::Step::A',
            );
    };

    like(
        $e,
        qr/\QFound a class which doesn't do the Stepford::Role::Step role: Test9::Step::A/,
        'cannot have an attribute that is both a dependency and production'
    );
}

done_testing();

sub _test_plan {
    my $runner      = shift;
    my $prefix      = shift;
    my $final_steps = shift;
    my $expect      = shift;
    my $desc        = shift;

    my $got_str = $runner->_make_root_graph_builder(
        [
            map { _prefix( $prefix, $_ ) }
                ref $final_steps ? @{$final_steps} : $final_steps
        ],
        {},
    )->graph->as_string;

    my $expect_str = 'Stepford::FinalStep' . "\n" . _plan_as_str(
        _prefix( $prefix, q{} ),
        $expect,
        1,
    );

    eq_or_diff(
        $got_str,
        $expect_str,
        $desc
    );
}

sub _prefix { return join '::', @_[ 0, 1 ] }

sub _plan_as_str {
    my $prefix = shift;
    my $plan   = shift;
    my $depth  = shift;

    my $str = q{};

    for my $step ( sort keys %{$plan} ) {
        $str .= q{ } x ( $depth * 4 ) . $prefix . $step . "\n";
        $str .= _plan_as_str( $prefix, $plan->{$step}, $depth + 1 )
            if $plan->{$step};
    }
    return $str;
}
