#!/usr/bin/env perl 

#
# This test assumes the JIRA Default Workflow
#

use strict;
use warnings;

use FindBin;
BEGIN { 
    my $file = $FindBin::RealBin;
    $file =~ s{/t/.*$}{/setup.pl};
    require $file;
    require "$FindBin::RealBin/test_config.pl";
};

use Test::More tests => 23;
use Data::Dumper qw(Dumper);
use POSIX qw(strftime);

use ZCME::Atlassian::JIRA::REST;
my $jira = ZCME::Atlassian::JIRA::REST->new(-account => $ZCME::Atlassian::JIRA::REST::test_config::test_account);
my $user = $jira->username();

my $issue_summary = 'Test Issue from transition.t';
my $issue = $jira->new_issue( 
    { 
	project => $ZCME::Atlassian::JIRA::REST::test_config::project,
	issuetype => $ZCME::Atlassian::JIRA::REST::test_config::issuetype,
	summary => $issue_summary,
    });
diag($issue->browse_url());

my $transition = $issue->get_transition(-name => "Start Progress");
isa_ok($transition, "ZCME::Atlassian::JIRA::REST::Issue::Transition");
is($transition->to(), 'In Progress', 'to()');
is($transition->name(), 'Start Progress', 'name()',);
ok(+(not $transition->hasScreen()), "hasScreen()");
$transition->do();
is($issue->get('status'), 'In Progress', 'status');

$transition = $issue->get_transition(-name => "Resolve Issue");
isa_ok($transition, "ZCME::Atlassian::JIRA::REST::Issue::Transition");
is($transition->to(), 'Resolved', 'to()');
is($transition->name(), 'Resolve Issue', 'name()');
ok($transition->hasScreen(), "hasScreen()");
$transition->set('resolution' => 'Done');
$transition->set('assignee' => $user);
$transition->comment("Transition Comment", ['role' => 'Administrators']);
$transition->do();

is($issue->get('status'), 'Resolved', 'status');
is($issue->get('assignee'), $user, 'assignee');
is($issue->get('resolution'), 'Done', 'resolution');

my $comments = $issue->get_comments();
is(scalar(@$comments), 1, 'comment created');
is($comments->[0]->body(), 'Transition Comment', 'comment body()');
is($comments->[0]->author()->name(), $user, 'comment author()');
is($comments->[0]->created()->mysql_date(), strftime('%Y-%m-%d', localtime()), 'comment created()');
my($type, $value) = $comments->[0]->visibility();
is($type, 'role', 'comment visibility type');
is($value, 'Administrators', 'comment visibility value');

$transition = $issue->get_transition(-to => "Closed");
isa_ok($transition, "ZCME::Atlassian::JIRA::REST::Issue::Transition");
is($transition->to(), 'Closed', 'to()');
is($transition->name(), 'Close Issue', 'name()');
ok($transition->hasScreen(), "hasScreen()");
$transition->do();
is($issue->get('status'), 'Closed', 'status');

$issue->delete();

__END__
