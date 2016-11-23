# -*- Perl -*-

use strict;
use warnings;

# https://docs.atlassian.com/software/jira/docs/api/REST/latest/

package ZCME::Atlassian::JIRA::REST;
use base qw(ZCME::REST);

use MIME::Base64 qw(encode_base64);
use Carp qw(croak confess);
use File::Path qw(make_path);

use ZCME::SecretsFile;
use ZCME::Atlassian::JIRA::REST::Issue;
use ZCME::Atlassian::JIRA::REST::Issue::New;
use ZCME::Atlassian::JIRA::REST::User;
use ZCME::Atlassian::JIRA::REST::Group;
use ZCME::Atlassian::JIRA::REST::Versions;
use ZCME::Atlassian::JIRA::REST::Filter;
use ZCME::Atlassian::JIRA::REST::Issue::Iterator;

sub new {
    my $self = shift;
    my %params = @_;
    my $account = $params{-account} || $ENV{'JIRA_AUTH_ACCOUNT'};
    $self = $self->SUPER::new();
    $self->{_secrets} = ZCME::SecretsFile->new(-filename => '.jira_auth',
					       -account => $account);
    return $self;
}

sub cache_dir {
    my $self = shift;
    my $dir = shift;
    if(defined($dir)) {
	-d $dir or die "$dir is not a directory.";
	-w _ or die "$dir is not writable.";
	-x _ or die "$dir is not executable.";
	$self->{_cache_dir} = $dir;
    } else {
	return $self->{_cache_dir};
    }
}

sub disable_cache {
    my $self = shift;
    # NOTE: Undef means we've disabled it, but the _cache_dir key not existing means we will use the default if available.
    $self->{_cache_dir} = undef;
}

sub username { 
    my $self = shift;
    return $self->{_secrets}->get('username');
}

sub password { 
    my $self = shift;
    return $self->{_secrets}->get('password');
}

sub base_url {
    my $self = shift;
    return $self->{_secrets}->get('base_url')."/rest/api/2";
}

sub server_url {
    my $self = shift;
    return $self->{_secrets}->get('base_url');
}

sub server_id {
    my $self = shift;
    my $server_id = $self->{_secrets}->get('server_id');
    unless(defined($server_id)) {
	die "No server_id defined for ".$self->{_secrets}->account().".\n";
    }
    return $server_id;
}

sub decorate_request { 
    my $self = shift;
    my $req = shift;
    $req->header("X-Atlassian-Token" => "no-check");
    $req->header("Authorization" => "Basic ".encode_base64($self->username().':'.$self->password(), ''));
}

sub format { return 'json'; }
sub response_format { return 'json'; }

sub _arrayref {
    my $value = shift;
    if(ref($value)) {
	return $value;
    } else {
	return [$value];
    }
}

sub fieldkey {
    my $self = shift;
    my $field_name = shift;
    unless(defined($self->{fields})) {
	$self->{fields} = $self->rest('GET', "field");
    }
    foreach my $field (@{$self->{fields}}) {
	if($field_name eq $field->{id}) {
	    return $field->{id};
	} elsif($field->{name} eq $field_name) {
	    return $field->{id};
	}
	# TODO: Contemplate support for Clause Names
    }
    return $field_name;
}

sub fieldname {
    my $self = shift;
    my $field_key = shift;
    unless(defined($self->{fields})) {
	$self->{fields} = $self->rest('GET', "field");
    }
    foreach my $field (@{$self->{fields}}) {
	if($field_key eq $field->{id}) {
	    return $field->{name};
	} elsif($field->{name} eq $field_key) {
	    return $field->{name};
	}
	# TODO: Contemplate support for Clause Names
    }
    return $field_key;
}

sub get_issue {
    my $self = shift;
    my $key = shift;

    return (__PACKAGE__.'::Issue')->new($self, $key); 
}

sub new_issue_object {
    my $self = shift;
    my $updates = shift;
    return (__PACKAGE__.'::Issue::New')->new($self, $updates); 
}

sub new_issue {
    my $self = shift;
    my $updates = shift;
    return $self->new_issue_object($updates)->save();
}

sub get_filter {
    my $self = shift;
    my $key = shift;
    defined($key) or return undef;
    my $filter;
    eval {
	$filter = (__PACKAGE__.'::Filter')->new($self, $key); 
    };
    die $@ if($@ and $@ !~ m/404 Not Found/);
    return $filter;
}

sub get_user {
    my $self = shift;
    my $key = shift;

    defined($key) or return undef;
    my $user = undef;
    eval {
	$user = (__PACKAGE__.'::User')->cache_retrieve($self, $key); 
    };
    die $@ if($@ and $@ !~ m/404 Not Found/ and $@ !~ m/No user found/);
    return $user;
}

sub get_group {
    my $self = shift;
    my $key = shift;

    defined($key) or return undef;
    my $group;
    eval {
	$group = (__PACKAGE__.'::Group')->new($self, $key); 
    };
    die $@ if($@ and $@ !~ m/404 Not Found/);
    return $group;
}

sub get_versions {
    my $self = shift;
    my $key = shift;

    defined($key) or return undef;
    return (__PACKAGE__.'::Versions')->new($self, $key); 
}

sub search {
    my $self = shift;
    my $jql = shift;

    my $searchRequest = {
	jql => $jql, 
	fields => ['*all'],
     };

    return (__PACKAGE__.'::Issue::Iterator')->new($self, $searchRequest);
}

sub link_type {
    my $self = shift;
    my $type = shift;
    unless(exists($self->{_issueLinkTypes})) {
	$self->{_issueLinkTypes} = $self->rest('GET' => 'issueLinkType')->{issueLinkTypes};
    }
    foreach my $linktype (@{$self->{_issueLinkTypes}}) {
	foreach my $direction (qw(inward outward)) {
	    if($linktype->{$direction} eq $type) {
		return ($linktype->{name},$direction);
	    }
	}
    }
    croak "Unknown link type $type";
}

1;

__END__
