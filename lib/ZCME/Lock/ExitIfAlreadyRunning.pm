# -*- Perl -*-
use strict;
use warnings;

package ZCME::Lock::ExitIfAlreadyRunning;
use FindBin qw($RealBin $RealScript);
use Digest::MD5 qw(md5_hex);
use Fcntl qw(:flock SEEK_END);
use IO::File;

my $dir = '/tmp/zcme_locks';
my $fh;
sub import {
    my $self = shift;
    my $string = shift || md5_hex($RealBin.'/'.$RealScript);
    unless(-d $dir) {
	eval {
	    mkdir($dir);
	};
    }
    my $file = "$dir/$string";
    $fh = IO::File->new(">>$file");
    my $status = flock($fh, LOCK_EX | LOCK_NB);
    exit unless $status;
}

1;
