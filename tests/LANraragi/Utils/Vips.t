use strict;
use warnings;
use v5.36;

use Test::More;
use Test::MockModule qw(strict);
use Cwd qw(getcwd);

my $cwd = getcwd();
require "$cwd/tests/mocks.pl";

my $module = Test::MockModule->new('LANraragi::Utils::Logging');
$module->redefine('get_logger', get_logger_mock());

use LANraragi::Utils::Vips;

if (!LANraragi::Utils::Vips::is_vips_loaded) {
    plan skip_all => "libvips is not installed";
};

use_ok('LANraragi::Utils::Vips');

note("test loading an image");
{
    my $image_path = "$cwd/tests/samples/reader.jpg";
    my $img = LANraragi::Utils::Vips::new_from_file($image_path);
    isnt($img, undef, "Should get an image");
    is(LANraragi::Utils::Vips::width($img), 2233, "Should be correct width");
    is(LANraragi::Utils::Vips::height($img), 1828, "Should be correct height");
}


note("test creating a blank image");
{
    my $img = LANraragi::Utils::Vips::black(320, 200);
    isnt($img, undef, "Should get an image");
    is(LANraragi::Utils::Vips::width($img), 320, "Should be correct width");
    is(LANraragi::Utils::Vips::height($img), 200, "Should be correct height");
}

note("test reading a pdf");
{
    my $doc_path = "$cwd/tests/samples/doc.pdf";
    my $pdf = LANraragi::Utils::Vips::new_from_file($doc_path);
    is(LANraragi::Utils::Vips::get_n_pages($pdf), 4, "Should get 4 pages");
    LANraragi::Utils::Vips::unref_image($pdf);

    # 0 = first page, 3 = last (fourth) page
    my $p4 = LANraragi::Utils::Vips::pdfload_page_dpi($doc_path, 3, 72);
    is(LANraragi::Utils::Vips::width($p4), 231, "Should be 231 pixels wide in 72 DPI");
    LANraragi::Utils::Vips::unref_image($p4);

    # This test breaks on Homebrew for some reason, whether vips uses magick/gs or poppler as the PDF backend. 
    # It's quite peculiar, but I'm willing to chalk this to a vips issue rather than us at this point. 
    if ( $^O ne 'darwin' ) {
        $p4 = LANraragi::Utils::Vips::pdfload_page_dpi($doc_path, 3, 90);
        is(LANraragi::Utils::Vips::width($p4), 288, "Should be 288 pixels wide in 90 DPI");
    }
   
}

note("jpeg buffer writing strips metadata and optimizes coding");
{
    my $img = LANraragi::Utils::Vips::new_from_file("$cwd/tests/samples/reader.jpg");

    # Baseline: Q-only encode via the raw FFI binding.
    require FFI::Platypus::Buffer;
    my ( $raw_buf, $raw_len );
    my $r = LANraragi::Utils::Vips::vips_image_write_to_buffer( $img, ".jpg", \$raw_buf, \$raw_len, "Q", 80, undef );
    is( $r, 0, "baseline Q-only encode succeeds" );
    my $baseline = FFI::Platypus::Buffer::buffer_to_scalar( $raw_buf, $raw_len );
    LANraragi::Utils::Vips::g_free($raw_buf);

    my $optimized = LANraragi::Utils::Vips::write_to_buffer( $img, ".jpg", 80 );
    ok( defined($optimized) && length($optimized) > 0, "optimized encode produces output" );
    ok( length($optimized) <= length($baseline), "stripped + optimal-Huffman output is no larger than baseline" );

    # Round-trip: the optimized bytes must decode with identical dimensions.
    my $rt = LANraragi::Utils::Vips::new_from_buffer($optimized);
    is( LANraragi::Utils::Vips::width($rt),  LANraragi::Utils::Vips::width($img),  "round-trip preserves width" );
    is( LANraragi::Utils::Vips::height($rt), LANraragi::Utils::Vips::height($img), "round-trip preserves height" );
    LANraragi::Utils::Vips::unref_image($rt);
    LANraragi::Utils::Vips::unref_image($img);
}

note("windows lib loading degrades gracefully when DLLs are missing");
{
    # Mock the imported alias inside the Vips namespace (redefining
    # FFI::CheckLib::find_lib would not retarget the compile-time import).
    my $mock = Test::MockModule->new('LANraragi::Utils::Vips');
    $mock->redefine( 'find_lib', sub { die "No library found\n"; } );
    is( LANraragi::Utils::Vips::_load_windows_libs(), 0, "loader returns false when DLLs are missing" );
    ok( LANraragi::Utils::Vips::is_vips_loaded(), "existing loaded state is untouched by the probe" );
}

done_testing();

1;