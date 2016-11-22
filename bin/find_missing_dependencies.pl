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
my $skip_scan = 0;
my $die_on_error = 0;
my $json_report;
my @force_modules = qw(Bundle::LWP Net::HTTP JSON JSON::PP Mozilla::CA XML::Parser XML::SAX XML::DOM Carp::Always Math::Round HTTP::Request File::ChangeNotify CGI LWP::Protocol::https);
GetOptions(
    "help" => \$help,
    "verbose" => \$verbose,
    "fetch" => \$fetch,
    "dir=s" => \$search_dir,
    "force=s" => \@force_modules,
    "skip-scan" => \$skip_scan,
    "die-on-error" => \$die_on_error,
    "json-report=s" => \$json_report,
    );
if($help) {
    die << "USAGE";
$0 [--help] 
$0 [--verbose] [--fetch] [--dir=DIR] [--force=MOD [--force=MOD [...]]] [--skip-scan] [--dir-on-error] [--json-report=FILE]
    --verbose      - human readable report at end
    --fetch        - install needed modules. default is to simply report.
    --dir          - directory to scan for needed dependencies ($search_dir)
    --force        - install this module even if it is already installed at system
    --die-on-error - stop execution when a needed module fails, default is keep going
    --json-report  - emit a JSON blob indicating what was and was not installed
USAGE
    ;
}

sub is_module_installed {
    my $module = shift;
    $module =~ s/^Bundle:://;
    my $err = `perl -c -I$RealBin/../lib -M$module -e 42 2>&1`;
    return ($err =~ m/syntax OK$/) ? 1 : undef;
}

my %modules = map {$_ => 'force'} @force_modules;
unless($skip_scan) {
    find(
	sub {
	    return unless -f;
	    return unless /\.(pm|pl|cgi)/;
	    return if $File::Find::dir =~ /external/;
	    my $fh = IO::File->new($_);
	    while(my $line = $fh->getline()) {
		if($line =~ m/^\s*use\s+([^\;\s]+)/) {
		    next if $line =~ m/ZCME|ZCM/;
		    $modules{$1} = 'ifneeded';
		}
	    }
	    
	}, 
	$search_dir);
}

my $report;
foreach my $module (sort keys %modules) {
    my $noforce = ($modules{$module} ne 'force');
    if($noforce and is_module_installed($module)) {
	$report->{ok}->{already_installed}->{$module} = 1;
    } else {
	if($fetch) {
	    CPAN::Shell->install($module);
	    if(is_module_installed($module)) {
		$report->{ok}->{newly_installed}->{$module} = 1;
	    } else {
		$report->{error}->{install_failed}->{$module} = 1;
		die "Failed to install $module.\n" if $die_on_error;
	    }
	} else {
	    $report->{error}->{needed}->{$module} = 1;
	}
    }
}

END {
    if(defined($report)) {
	if($verbose) {
	    print "===REPORT===\n";
	    foreach my $key (sort keys %$report) {
		print "$key\n";
		foreach my $reason (sort keys %{$report->{$key}}) {
		    print "\t$reason\n";
		    foreach my $module (sort keys %{$report->{$key}->{$reason}}) {
			print "\t\t$module\n";
		    }
		}
	    }
	}
	if($json_report) {
	    require JSON;
	    require IO::File;
	    my $json = JSON::encode_json($report);
	    my $fh = IO::File->new(">$json_report");
	    print $fh $json;
	    close $fh;
	}
    }
}
