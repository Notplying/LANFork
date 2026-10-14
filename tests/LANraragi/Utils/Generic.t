use strict;
use warnings;
use utf8;
use Data::Dumper;

use Test::More;
use Test::Deep;

BEGIN { use_ok('LANraragi::Utils::Generic'); }

note('testing rules flattening...');

{
    my $tagrules = [
        [ 'strip_ns', 'namespace', '' ],
        [ 'replace', 'scream', 'Please Stop' ],
        [ 'remove', 'ping', '']
    ];

    my @flattened_rules = LANraragi::Utils::Generic::flat(@$tagrules);
    cmp_deeply(
        \@flattened_rules,
        [
            'strip_ns',
            'namespace',
            '',
            'replace',
            'scream',
            'Please Stop',
            'remove',
            'ping',
            ''
        ],
        'flattened rules');
}

note('testing job coalescing...');

{
    my $calls = 0;
    my ( $id1, $new1 ) = LANraragi::Utils::Generic::coalesce_job( "thumb:test1", 120, sub { return "job-" . ++$calls; } );
    is( $new1, 1,      'first call runs the function' );
    is( $id1,  "job-1", 'first call returns the new job id' );

    my ( $id2, $new2 ) = LANraragi::Utils::Generic::coalesce_job( "thumb:test1", 120, sub { return "job-" . ++$calls; } );
    is( $new2, 0,      'second call within TTL does not run the function' );
    is( $id2,  "job-1", 'second call reuses the pending job id' );
    is( $calls, 1,      'function ran exactly once for coalesced key' );

    my ( $id3, $new3 ) = LANraragi::Utils::Generic::coalesce_job( "thumb:test2", 120, sub { return "job-" . ++$calls; } );
    is( $new3, 1,      'different key runs the function' );
    is( $id3,  "job-2", 'different key gets its own job id' );
}

{
    my $calls = 0;
    my $code = sub { return "job-" . ++$calls; };
    LANraragi::Utils::Generic::coalesce_job( "thumb:expiry", 1, $code );
    sleep 2;
    my ( $id, $new ) = LANraragi::Utils::Generic::coalesce_job( "thumb:expiry", 1, $code );
    is( $new,   1,       'expired entry runs the function again' );
    is( $calls, 2,       'function ran once per TTL window' );
    is( $id,    "job-2", 'new job id after expiry' );
}

done_testing();