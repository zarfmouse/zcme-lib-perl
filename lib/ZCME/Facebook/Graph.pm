# -*- Perl -*-

use strict;
use warnings;

package ZCME::Facebook::Graph;
use base qw(ZCME::REST);

use ZCME::Facebook::Graph::OAuth;
use ZCME::Facebook::Graph::TestUser;

use CGI qw(escape);
use Data::Dumper qw(Dumper);
use Carp;

use ZCME::SecretsFile;

sub new {
    my $self = shift;
    my %params = @_;
    $self = $self->SUPER::new();

    $self->{_oauth} = (__PACKAGE__.'::OAuth')->new(-account => $params{-account},
						   -redirect_uri => $params{-redirect_uri});

    return $self;
}

sub base_url {
    my $self = shift;
    return 'https://graph.facebook.com/v2.8';
}

sub format { return undef; }
sub response_format { return 'json'; }

sub oauth {
    my $self = shift;
    return $self->{_oauth};
}

sub debug_token {
    my $self = shift;
    my $token = shift;

    my $app_token = $self->oauth()->app_access_token();
    my $resp = $self->rest("GET", ["debug_token", 
				   {
				       access_token => $app_token,
				       input_token => $token,
				   }]);
    return $resp;
}

sub test_users {
    my $self = shift;
    my $app_id = $self->oauth()->client_id();
    my $resp = $self->rest("GET", ["$app_id/accounts/test-users",
				   {
				       access_token => $self->oauth()->app_access_token()
				   }]);
    my @retval = map { (__PACKAGE__.'::TestUser')->new($self, $_) } @{$resp->{data}}; 
    return \@retval;
}



1;

__END__
