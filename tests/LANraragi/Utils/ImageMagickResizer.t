use strict;
use warnings;
use v5.36;

use Test::More;

use LANraragi::Utils::ImageMagickResizer;

# Skip (not fail) where PerlMagick isn't available,
# e.g. MSYS2 Windows envs which use libvips instead.
my $has_magick = eval { require Image::Magick; 1 };
if (!$has_magick) {
    plan skip_all => "Image::Magick is not installed";
}

use Test::MockModule qw(strict);
use Cwd qw(getcwd);

my $cwd = getcwd();
require "$cwd/tests/mocks.pl";

my $module = Test::MockModule->new('LANraragi::Utils::Logging');
$module->redefine('get_logger', get_logger_mock());

setup_redis_mock();

use_ok('LANraragi::Utils::ImageMagickResizer');

my $image_path = "$cwd/tests/samples/reader.jpg";
open my $fh, '<:raw', $image_path or die "Cannot open $image_path: $!";
my $image_data = do {
    local $/;
    <$fh>
};
close $fh;


note("testing page resizing");
{
    my $resizer = LANraragi::Utils::ImageMagickResizer->new;

    my $resized_data = $resizer->resize_page($image_data, 80, 'jpg');
    ok(defined $resized_data, "Image was resized");

    my $img = Image::Magick->new;
    $img->BlobToImage($resized_data);
    my $width = $img->Get('width');
    is($width, 1064, "Page image width is 1064");
}

note("testing thumbnail resizing");
{
    my $resizer = LANraragi::Utils::ImageMagickResizer->new;

    my $resized_data = $resizer->resize_thumbnail($image_data, 80, 0, 'jpg');
    ok(defined $resized_data, "Image was resized");

    my $img = Image::Magick->new;
    $img->BlobToImage($resized_data);
    my $width = $img->Get('width');
    is($width, 500, "Thumbnail width is 500");
}

done_testing();
