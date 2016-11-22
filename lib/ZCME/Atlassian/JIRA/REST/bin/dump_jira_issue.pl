#!/usr/bin/env perl

use strict;
use warnings;

use FindBin qw($RealBin);
BEGIN {require "$RealBin/../setup.pl"};

use ZCME::Atlassian::JIRA::REST;

use Data::Dumper qw(Dumper);

use Getopt::Long qw(GetOptions);
my $help = 0;
my $VERBOSE = 0;
my $account;
GetOptions(
    "help" => \$help,
    "verbose" => \$VERBOSE,
    "account=s" => \$account,
    );


my $jira=ZCME::Atlassian::JIRA::REST->new($account);

my $issue=$jira->get_issue(shift);

print Dumper($issue->{_content});

__END__

