#!/usr/bin/env perl

use strict;
use warnings;

use FindBin qw($RealBin);
BEGIN {require "$RealBin/../setup.pl"};

use Data::Dumper qw(Dumper);
use IPC::Cmd qw(can_run);
use File::Temp qw(tempfile);
use Data::Dumper qw(Dumper);
use Storable qw(lock_store lock_retrieve);
use JSON qw(encode_json decode_json);
use IO::File;

use ZCME::HereDoc qw(here);

use Getopt::Long qw(GetOptions);
my $help = 0;
my $VERBOSE = 0;
my $input_format;
my $output_format;
my $type = 'HASH';
my $edit = 0;
my $editor = $ENV{'VISUAL'} || $ENV{'EDITOR'} || 'emacs';
GetOptions(
    "help" => \$help,
    "verbose" => \$VERBOSE,
    "edit" => \$edit,
    "input-format=s" => \$input_format,
    "output-format=s" => \$output_format,
    );
my $input_file = shift;
my $output_file = shift;

my %formats = (
    json => {
	to_perl => \&json_to_perl,
	from_perl => \&json_from_perl,
    },
    storable => {
	to_perl => \&lock_retrieve,
	from_perl => \&lock_store,
    },
    dumper => {
	to_perl => \&dumper_to_perl,
	from_perl => \&dumper_from_perl,
    },
    legacy_config => {
	to_perl => \&legacy_config_to_perl,
	from_perl => \&legacy_config_from_perl,
    },
    );
my %types = (
    HASH => 1,
    ARRAY => 1,
    );

my $Usage = here(<<"USAGE");
# $0 [--help] 
# $0 [--verbose] [--edit] [--editor=PATH] [--input-format=FORMAT] [--output-format=FORMAT] [--type=TYPE] INPUT_FILE [OUTPUT_FILE]
    --edit - Edit the data in Data::Dumper format before output.
USAGE
    ;
$Usage .= "    --editor - editor to use in edit mode.";
$Usage .= defined($editor) ? " ($editor)\n" : "\n";
$Usage .= "    FORMAT:\n        ".join("\n        ", sort keys %formats)."\n";
$Usage .= "    TYPES ($type):\n        ".join("\n        ", sort keys %types)."\n";

die "$Usage" if $help;
die "--input-file required\n$Usage" unless defined($input_file);

($input_format) = ($input_file =~ m/\.([^\.]+)$/) unless(defined($input_format));
die "Invalid input format: $input_format\n$Usage" unless exists($formats{$input_format});

if($edit) {
    die "Can not find editor: $editor\n$Usage" unless(can_run($editor));
    $output_file = $input_file unless(defined($output_file));
}

unless(defined($output_format)) {
    if(defined($output_file)) {
	($output_format) = ($output_file =~ m/\.([^\.]+)$/);
	exists($formats{$output_format}) or $output_format = undef;
    }
}
$output_format = $input_format unless(defined($output_format));

die "Invalid output format: $output_format\n$Usage" unless exists($formats{$output_format});

die "Invalid type: $type\n$Usage" unless exists($types{$type});

my $data;
if(-f $input_file) {
    $data = $formats{$input_format}->{to_perl}->($input_file);
} else {
    if($type eq 'HASH') {
	$data = { foo => 'bar' };
    } elsif($type eq 'ARRAY') {
	$data = [ { foo => 'bar' }, { foo => 'bar' } ];
    } else {
	die "Invalid type: $type.";
    }
}

if($edit) {
    my($fh, $filename) = tempfile("data_file_editXXXXXX", SUFFIX => '.pl', UNLINK => 1);
    $formats{'dumper'}->{from_perl}->($data, $filename);
    system("$editor $filename");
    $data = $formats{'dumper'}->{to_perl}->($filename);
}


if($output_format eq 'storable' and not defined($output_file)) {
    $output_format = 'dumper';
} 
$formats{$output_format}->{from_perl}->($data, $output_file);

sub _get_write_fh {
    my $filename = shift;
    if(defined($filename)) {
	my $fh = IO::File->new(">$filename") or die "open($filename): $!";
	return $fh;
    } else {
	return \*STDOUT;
    }
}

sub json_to_perl {
    my $filename = shift;
    my $json = join('',IO::File->new($filename)->getlines());
    return decode_json($json);
}

sub json_from_perl {
    my $data = shift;
    my $fh = _get_write_fh(shift);
    print $fh encode_json($data);
    close($fh);
}

sub dumper_to_perl {
    my $filename = shift;
    my $source = join('',IO::File->new($filename)->getlines());
    use vars qw($VAR1);
    my $perl = eval($source);
    die $@ if $@;
    return $perl;
}

sub dumper_from_perl {
    my $data = shift;
    my $fh = _get_write_fh(shift);
    print $fh Dumper($data);
    close($fh);
}

sub legacy_config_to_perl {
   my $filename = shift;
   my $source = join('',IO::File->new($filename)->getlines());
   no strict 'vars';
   eval("package ftl_legacy_config; $source");
   use strict 'vars';
   die $@ if $@;
   my $perl = {};
   foreach my $key (keys %ftl_legacy_config::) {
       no strict 'refs';
       if(defined(${"ftl_legacy_config::$key"})) {
	   $perl->{$key} = ${"ftl_legacy_config::$key"};
       } elsif(%{"ftl_legacy_config::$key"}) {
	   $perl->{$key} = \%{"ftl_legacy_config::$key"};
       } elsif(@{"ftl_legacy_config::$key"}) {
	   $perl->{$key} = \@{"ftl_legacy_config::$key"};
       }
   }
   return $perl;
}

sub legacy_config_from_perl {
    die "Can not convert to legacy_config.\n";
}


__END__

