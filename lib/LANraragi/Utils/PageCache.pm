package LANraragi::Utils::PageCache;

use v5.36;

use strict;
use warnings;
use utf8;

use List::Util qw(min max);
use CHI;
use Config;

use LANraragi::Utils::Logging  qw(get_logger);
use LANraragi::Utils::TempFolder qw(get_temp);

use constant IS_UNIX => ( $Config{osname} ne 'MSWin32' );

# Contains all functions related to caching entire pages
use Exporter 'import';
our @EXPORT_OK = qw(fetch put clear remove);

my $cache = undef;

sub calc_max_size() {
    return max(0, min(LANraragi::Model::Config->get_tempmaxsize, 4096));
}

sub initialize() {
    my $logger = get_logger( "PageCache", "lanraragi" );
    my $mb = calc_max_size();

    if ( IS_UNIX ) {
        # FastMmap expects a human-readable size like "500m" (see CHI docs).
        my $disk_size = $mb . "m";
        $logger->debug( "Initializing cache, disk size: " . $disk_size );

        $cache = CHI->new(
            driver     => 'FastMmap',
            cache_size => $disk_size,
            root_dir => get_temp,
        );
    } else {
        # CHI::Driver::Memory is size-aware in bytes with LRU discard
        # (see CHI "SIZE AWARENESS" docs). Passing "500m" would numify to
        # 500 bytes and evict every page immediately, so convert MB to bytes.
        my $max_bytes = $mb * 1024 * 1024;
        $logger->debug( "Initializing cache, max size bytes: " . $max_bytes );

        $cache = CHI->new(
            driver     => 'Memory',
            global => 1,
            max_size => $max_bytes,
        );
    }
}

# Fetches data from cache if available. Returns undef if nothing is there.
# NOTE: Intentionally no per-call logging here. fetch/put run on every page
# served, and on Windows each get_logger() reopens the log file via
# CreateFile (see RotatingLog::refresh_logger_handle), serializing all
# concurrent page requests behind file + flock operations.
sub fetch( $key ) {
    if (!defined($cache)) {
        initialize;
    }

    return $cache->get($key);
}

# Attempts to store data in the cache. Do not assume that fetch will work immediately after, cache may be disabled etc
sub put( $key, $content ) {
    if (!defined($cache)) {
        initialize;
    }

    $cache->set($key, $content);
}

sub clear() {
    if (!defined($cache)) {
        initialize;
    }

    my $logger = get_logger( "PageCache", "lanraragi" );
    $logger->debug("Clearing cache");
    $cache->clear();
}

sub remove( $key ) {
    if (!defined($cache)) {
        initialize;
    }

    $cache->remove($key);
}

1;
