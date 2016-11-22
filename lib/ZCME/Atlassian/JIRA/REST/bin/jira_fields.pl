#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

use FindBin;
BEGIN { 
    my $file = $FindBin::RealBin;
    $file =~ s{/lib/.*$}{/setup.pl};
    require $file;
};

use ZCME::Atlassian::JIRA::REST;

use Getopt::Long qw(GetOptions);
my $account;
my $help = 0;
my $all = 0;
GetOptions(
    "account=s" => \$account,
    "help" => \$help,
    "verbose" => \$ZCME::REST::VERBOSE,
    "all" => \$all,
    );
if($help) {
    die << "USAGE";
$0 [--account=ACCOUNTSTR] [--verbose] [--all]
$0 [--help] 
        --all - Include standard non-custom fields.
USAGE
;
}

my $jira = ZCME::Atlassian::JIRA::REST->new($account);

my $fields = $jira->rest('GET' => 'field');
foreach my $field (@$fields) {
    print "$field->{name} ($field->{id})\n" if ($field->{custom} or $all);
}

