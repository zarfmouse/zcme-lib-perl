#!/usr/bin/env perl 

use strict;
use warnings;

use FindBin;
BEGIN { 
    my $file = $FindBin::RealBin;
    $file =~ s{/t/.*$}{/setup.pl};
    require $file;
    require "$FindBin::RealBin/test_config.pl";
};

use Test::More tests => 21;
use Data::Dumper qw(Dumper);

use ZCME::Atlassian::JIRA::REST;
my $jira = ZCME::Atlassian::JIRA::REST->new(-account => $ZCME::Atlassian::JIRA::REST::test_config::test_account);

my $issue_summary = 'Test Issue from create.t';
my $subissue_summary = 'Test Sub Issue from create.t';

# CREATE
my $issue = $jira->new_issue( 
    { 
	project => $ZCME::Atlassian::JIRA::REST::test_config::project,
	issuetype => $ZCME::Atlassian::JIRA::REST::test_config::issuetype,
	summary => $issue_summary,
    });
isa_ok($issue, "ZCME::Atlassian::JIRA::REST::Issue");
diag($issue->browse_url());
my $issue_key = $issue->key();
like($issue_key, qr/^${ZCME::Atlassian::JIRA::REST::test_config::project}-/, 'issue is created right away');
# Sub-Issue Create
my $subissue = $jira->new_issue( 
    { 
	parent => $issue->key(),
	project => $ZCME::Atlassian::JIRA::REST::test_config::project,
	issuetype => $ZCME::Atlassian::JIRA::REST::test_config::subissuetype,
	summary => $subissue_summary,
    });
diag($subissue->browse_url());
ok($subissue->is_subtask(), 'subtask');
my $subissue_key = $subissue->key();

# READ
is($issue->get('summary'), $issue_summary, 'summary was set');
is($issue->get('project'), $ZCME::Atlassian::JIRA::REST::test_config::project, 'project was set');
is($issue->get('issuetype'), $ZCME::Atlassian::JIRA::REST::test_config::issuetype ,'issuetype was set');
is($issue->get('reporter'), $jira->username(), 'reporter was set');
is($subissue->get('summary'), $subissue_summary, 'subtask summary');

# UPDATE 
my $test_label = 'update_issue_test';
ok((not $issue->is_dirty()), 'is_dirty()');
ok(+(not $issue->exists('labels' => $test_label)), 'exists()');

# Setting a field value makes the issue dirty until it is saved.
$issue->add('labels' => $test_label);
ok($issue->is_dirty(), 'is_dirty()');

# Getter does not return the value until it is saved.
ok(not $issue->exists('labels' => $test_label));

# After saving the changes, getter returns new values and issue is clean.
$issue->save();
ok((not $issue->is_dirty()));
ok($issue->exists('labels' => $test_label));

# Verify new values really were saved by retrieving the issue again.
$issue = $jira->get_issue($issue_key);
ok($issue->exists('labels' => $test_label));
my $old_labels = $issue->get('labels');
$issue->set('labels' => [qw(foo bar), $test_label]);
$issue->save();
my $new_labels = $issue->get('labels');
is(scalar(@$new_labels), 3);
ok($issue->exists(labels=>'foo'));
ok($issue->exists(labels=>'bar'));
ok($issue->exists(labels=>$test_label));

# DELETE
$subissue->delete();
eval {
    $subissue = $jira->get_issue($subissue_key);
};
like($@, qr/404 Not Found/);

$issue->delete();
eval {
    $issue = $jira->get_issue($issue_key);
};
like($@, qr/404 Not Found/);

__END__
