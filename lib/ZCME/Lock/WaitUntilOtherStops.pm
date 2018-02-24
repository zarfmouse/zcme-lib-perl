# -*- Perl -*-
use strict;
use warnings;

package ZCME::Lock::WaitUntilOtherStops;
use FindBin qw($RealBin $RealScript);
use Digest::MD5 qw(md5_hex);
use Fcntl qw(:flock SEEK_END);
use IO::File;

my $dir = '/tmp/zcme_locks';
my $fh;
sub import {
    my $self = shift;
    my $string = shift || die "Must specify a key.";
    unless(-d $dir) {
	eval {
	    mkdir($dir);
	};
    }
    my $file = "$dir/$string";
    $fh = IO::File->new(">>$file");
    flock($fh, LOCK_EX) or die "flock('$dir/$string', LOCK_EX): $!";
}

1;
