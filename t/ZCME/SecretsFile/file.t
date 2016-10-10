#!/usr/bin/env perl 

use strict;
use warnings;

use FindBin;
BEGIN { 
    my $file = $FindBin::RealBin;
    $file =~ s{/t/.*$}{/setup.pl};
    require $file;
};

use Test::More tests => 16;

use File::stat;
use Storable qw(lock_store);

use ZCME::SecretsFile;

my $dir = '/tmp';
my $filename = '.zcme_testfile';
my $file = "$dir/$filename";

sub clean {
    if(-f $file) {
	unlink($file) or die "unlink($filename): $!";
    }
}
&clean();
END { &clean() };

my $secrets = ZCME::SecretsFile->new(
    -dir => $dir,
    -filename => $filename,
    -account => 'test',
);

ok(-f $file, "created $file");
ok(-r $file, "readable $file");
ok(-w $file, "writable $file");
my $st = stat($file);
is($st->mode & 0777, 0600, 'secure $file');

is($secrets->account(), 'test', 'account');
$secrets->set('username' => 'foo');
is($secrets->get('username'), 'foo', 'set/get');
$secrets->set('password' => 'bar');
is($secrets->get('password'), 'bar', 'set/get');

$secrets->account('test2');
is($secrets->get('username'), undef, 'not yet set in 2nd account');
is($secrets->get('password'), undef, 'not yet set in 2nd account');
$secrets->set('username' => 'foo2');
is($secrets->get('username'), 'foo2', 'set/get with 2nd account');
$secrets->set('password' => 'bar2');
is($secrets->get('password'), 'bar2', 'set/get with 2nd account');

$secrets = ZCME::SecretsFile->new(
    -dir => $dir,
    -filename => $filename,
    -account => 'test',
);
is($secrets->get('username'), 'foo', 'values persist');
is($secrets->get('password'), 'bar', 'values persist');

$secrets = ZCME::SecretsFile->new(
    -dir => $dir,
    -filename => $filename,
    -account => 'test2',
);
is($secrets->get('username'), 'foo2', 'values persist with 2nd account');
is($secrets->get('password'), 'bar2', 'values persist with 2nd account');

my $invalid_data = {
    foo => [],
};
lock_store $invalid_data => $file;
eval {
    $secrets = ZCME::SecretsFile->new(
	-dir => $dir,
	-filename => $filename,
	-account => 'test',
	);
};
if($@) {
    pass("invalid data throws exception");
} else {
    pass("invalid data throws exception");
}

__END__







