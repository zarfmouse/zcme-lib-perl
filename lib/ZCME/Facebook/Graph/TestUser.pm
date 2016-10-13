# -*- Perl -*-

use strict;
use warnings;
use v5.10;

package ZCME::Facebook::Graph::TestUser;
use base qw(ZCME::REST::Object);
use Carp qw(carp croak);

our $VERBOSE = 0;

sub new {
    my $class = shift;
    my $self=$class->SUPER::new(shift);
    $self->{_content} = shift;
    return $self;
}

sub access_token {
    my $self = shift;
    return $self->{_content}->{access_token};
}

sub login_url {
    my $self = shift;
    return $self->{_content}->{login_url};
}

sub id {
    my $self = shift;
    return $self->{_content}->{id};
}

sub _flatten {
    my @flat = ();
    foreach my $val (@_) {
        if(ref($val) eq 'ARRAY') {
            push(@flat, _flatten(@$val));
        } else {
            push(@flat, $val);
        }
    }
    return @flat;
}

sub _comma {
    return join(',', _flatten(shift));
}

sub install {
    my $self = shift;
    my %params = @_;
    my $access_token = $self->rest_object()->oauth()->app_access_token();
    my $data = {
	installed => 'true',
	owner_access_token => $access_token,
	access_token => $access_token,
	uid => $self->id(),
    };
    if(defined($params{-permissions})) {
	$data->{permissions} = _comma($params{-permissions});
    }
    if(defined($params{-name})) {
	$data->{name} = $params{-name};
    }
    my $app_id = $self->rest_object()->oauth()->client_id();
    $self->{_content} = $self->rest("POST", "$app_id/accounts/test-users", $data);
}

1;
