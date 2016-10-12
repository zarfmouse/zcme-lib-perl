# -*- Perl -*-

use strict;
use warnings;

package ZCME::Facebook::Graph::OAuth;
use base qw(ZCME::REST);

use CGI qw(escape);
use Carp;
use URI;
use URI::QueryParam;

use ZCME::SecretsFile;

sub new {
    my $self = shift;
    my %params = @_;
    $self = $self->SUPER::new();

    my $account = $params{-account};
    $self->{_redirect_uri} = $params{-redirect_uri};

    $self->{_secrets} = ZCME::SecretsFile->new(-filename => '.facebook_tokens',
					       -account => $account);
    return $self;
}

sub base_url {
    my $self = shift;
    return 'https://graph.facebook.com/v2.8/oauth';
}

sub format { return undef; }
sub response_format { return 'json'; }

sub client_id {
    my $self = shift;
    my $client_id = $self->{_secrets}->get('client_id');
    defined($client_id) or die "client_id required in secrets";
    return $client_id;
}

sub client_secret {
    my $self = shift;
    my $client_secret = $self->{_secrets}->get('client_secret');
    defined($client_secret) or die "client_secret required in secrets";
    return $client_secret;
}

sub redirect_uri {
    my $self = shift;
    return $self->{_redirect_uri} || 
	"https://www.facebook.com/connect/login_success.html";
}

sub login_uri {
    my $self = shift;
    
    my $client_id = $self->client_id();
    my $redirect_uri = $self->redirect_uri();
    return "https://www.facebook.com/v2.8/dialog/oauth?client_id=".escape($client_id)."&redirect_uri=".escape($redirect_uri);
}

sub extract_code_from_uri {
    my $self = shift;
    my $uri = URI->new(shift);
    my $code = $uri->query_param('code');
    return $code;
}

sub user_access_token {
    my $self = shift;
    my %params = @_;

    if(defined($params{-code})) {
	my $resp = $self->rest("GET", ["access_token", 
				       {
					   client_id => $self->client_id(),
					   redirect_uri => $self->redirect_uri(),
					   client_secret => $self->client_secret(),
					   code => $params{-code},
				       }]);
	$self->{_secrets}->set("user_access_token" => 
			       $resp->{access_token});
	$self->{_secrets}->set("user_access_token_expires_at" => 
			       $resp->{expires_in} + time());
	return $self->{_secrets}->get("user_access_token");
    } elsif(defined($self->{_secrets}->get("user_access_token")) and 
	    $self->{_secrets}->get("user_access_token_expires_at") > time()) {
	return $self->{_secrets}->get("user_access_token");
    } else {
	return undef;
    }
}

sub app_access_token {
    my $self = shift;
    unless(defined($self->{_secrets}->get("app_access_token"))) {
	my $resp = $self->rest("GET", ["access_token", 
				       {
					   client_id => $self->client_id(),
					   client_secret => $self->client_secret(),
					   grant_type => "client_credentials",
				       }]);
	$self->{_secrets}->set("app_access_token" => $resp->{access_token});
    }
    return $self->{_secrets}->get("app_access_token");
}


1;

__END__
