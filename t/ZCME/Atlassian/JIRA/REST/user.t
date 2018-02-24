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

use Test::More tests => 12;

use ZCME::Atlassian::JIRA::REST;
use Data::Dumper qw(Dumper);
my $jira = ZCME::Atlassian::JIRA::REST->new(-account => $ZCME::Atlassian::JIRA::REST::test_config::test_account);
my $username = $jira->username();
my $user = $jira->get_user($username);
ok($user->isa('ZCME::Atlassian::JIRA::REST::User'), 'class');
like($user->emailAddress(), qr/^[^\@]+\@[^\@]+$/, 'emailAddress');
cmp_ok(length($user->name()), '>', 0, 'name');
cmp_ok(length($user->displayName()), '>', 0, 'displayName');
ok((not defined($user->memberOf('sldkjflkdsjfds'))), 'not memberOf');
ok($user->avatarUrl() =~ m/^http/, 'get the biggest one by default');
ok($user->avatarUrl(16) =~ m/^http/, 'one dimension is ok');
ok($user->avatarUrl('16x16') =~ m/^http/, 'precise amount is ok');
ok($user->avatarUrl(1000) =~ m/^http/, 'too big is ok');
ok($user->avatarUrl(1) =~ m/^http/, 'too small is ok');

my $email = $user->emailAddress();

$user = $jira->get_user($email);
ok($user->isa('ZCME::Atlassian::JIRA::REST::User'), 'class by email');
ok($user->name() eq $username, 'name by email');

# TODO: 
#   $user->assignable()
#   $user->memberOf()
#   $issue->get_user()

__END__




