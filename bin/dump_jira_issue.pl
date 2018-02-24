#!/usr/bin/env perl

use strict;
use warnings;
use v5.10;

use FindBin qw($RealBin);
BEGIN { require "$RealBin/../setup.pl" };

use ZCME::Atlassian::JIRA::REST;

my $jira = ZCME::Atlassian::JIRA::REST->new();
my $issue = $jira->get_issue(shift);
$issue->expand('changelog');
print Data::Dumper::Dumper($issue->{_content});


__END__




