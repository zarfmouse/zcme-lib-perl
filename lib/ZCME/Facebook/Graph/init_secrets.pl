#!/usr/bin/env perl 

use strict;
use warnings;

use FindBin;
BEGIN { 
    my $file = $FindBin::RealBin;
    $file =~ s{/lib/.*$}{/setup.pl};
    require $file;
};

use CGI qw(escape);
use Data::Dumper qw(Dumper);

use ZCME::SecretsFile;
use ZCME::Facebook::Graph;

use Getopt::Long qw(GetOptions);
my $help = 0;
my $VERBOSE = 0;
my $account = 'admin';
my $reset = 0;
GetOptions(
    "help" => \$help,
    "verbose" => \$VERBOSE,
    "account=s" => \$account,
    "reset" => \$reset,
    );

my $Usage = <<"USAGE";
$0 [--help]
$0 [--verbose] [--account=STR]
USAGE
    ;

$help and die $Usage;

my $secrets = ZCME::SecretsFile->new(
    -filename => ".facebook_tokens",
    -account => $account,
);

$|=1;

foreach my $key (qw(client_id client_secret)) {
    if((!defined($secrets->get($key))) or $reset) {
	print "$key: ";
	my $val = <>;
	chomp($val);
	$secrets->set($key => $val);
    }
}

my $facebook = ZCME::Facebook::Graph->new(-account => $account);
my $oauth = $facebook->oauth();

my $app_token = $oauth->app_access_token();
my $token = $oauth->user_access_token();

unless(defined($token)) {
    my $login_uri = $oauth->login_uri();
    print "Visit: $login_uri\n";
    print "URI with Code: ";
    my $uri = <>;
    chomp($uri);
    my $code = $oauth->extract_code_from_uri($uri);
    $token = $oauth->user_access_token(-code => $code);
}

print Dumper($facebook->debug_token($token));
print Dumper($facebook->debug_token($app_token));

