#!/usr/bin/env perl

$|=1;

use strict;
use warnings;

use FindBin qw($RealBin);
require "$RealBin/../setup.pl";

use File::Find;
use IO::File;
use CPAN;

use Getopt::Long qw(GetOptions);
my $help = 0;
my $verbose = 0;
my $fetch = 0;
my $search_dir = "$RealBin/..";
GetOptions(
    "help" => \$help,
    "verbose" => \$verbose,
    "fetch" => \$fetch,
    "dir=s" => \$search_dir,
    );
if($help) {
    die << "USAGE";
$0 [--help] 
$0 [--verbose] [--fetch] [--dir=DIR]
USAGE
    ;
}

my %found = ();
find(
    sub {
	return unless -f;
	return unless /\.(pm|pl|cgi)/;
	return if $File::Find::dir =~ /external/;
	my $fh = IO::File->new($_);
	while(my $line = $fh->getline()) {
	    if($line =~ m/^\s*use\s+([^\;\s]+)/) {
		next if $line =~ m/FortyTwoLines|ZCM/;
		$found{$1} = 1;
	    }
	}

    }, 
    $search_dir);

my %cpan = ();
foreach my $module (sort keys %found) {
    print "Checking $module..." if $verbose;
    my $err = `perl -c -I$RealBin/../lib -M$module -e 42 2>&1`;
    if($err =~ m/syntax OK$/) {
	print "ok.\n" if $verbose;
    } else {
	print "missing.\n" if $verbose;
	$cpan{$module} = $module;
    }
}

foreach my $module (keys %cpan) {
    if($fetch) {
	print "\n\n-----\nInstalling $module.\n----\n\n" if $verbose;
	CPAN::Shell->install($module);
    } else {
	print "cpan $module\n";
    }
}
