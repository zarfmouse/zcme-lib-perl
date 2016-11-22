# -*- Perl -*-

use strict;
use warnings;
use v5.10;

package ZCME::Atlassian::JIRA::REST::User;
use base qw(ZCME::REST::Object);
use Scalar::Util qw(looks_like_number);
use Data::Dumper qw(Dumper);
use Carp qw(carp croak);
use Storable qw(lock_store lock_retrieve);
use File::Path qw(make_path);

our $VERBOSE = 0;

our $CACHE_TTL = 1; # days

sub new {
    my $class = shift;
    my $self=$class->SUPER::new(shift);
    my $key_or_content = shift;
    if(ref($key_or_content) eq 'HASH') {
	$self->{_content} = $key_or_content;
	$self->{_key} = $self->{_content}->{name};
    } elsif($key_or_content =~ /\@/) { 
	$self->search_by_email($key_or_content);
    } else {
	$self->{_key} = $key_or_content;
	$self->refresh();
    }
    return $self;
}

sub key { 
    my $self = shift;
    return $self->{_key};
}

sub refresh {
    my $self = shift;
    $self->{_content} = $self->rest('GET', ["user", { username => $self->{_key}, expand => 'groups' }]);
    $self->cache_store();
}

sub cache_file {
    my $class_or_self = shift;
    my $key;
    my $rest;
    if(ref($class_or_self)) {
	$key = $class_or_self->key();
	$rest = $class_or_self->rest_object();
    } else {
	$key = shift;
	$rest = shift;
    }
    my $cache_dir = $rest->cache_dir();
    return undef unless (defined($cache_dir));
    my($sub1,$sub2,$sub3) = ($key =~ m/^(((.).?).?)/);
    my $dir = "$cache_dir/userss/$sub3/$sub2/$sub1";
    unless(-d $dir) {
	make_path($dir);
    }
    return "$dir/$key.storable";
}

sub cache_retrieve {
    my $class = shift;
    my $rest = shift;
    my $key = shift;

    my $cache_file = $class->cache_file($key, $rest);
    if(defined($cache_file) and -f $cache_file) {
	my $cache_obj = lock_retrieve($cache_file);
	$cache_obj->rerest($rest);
	if(-M $cache_file < $CACHE_TTL) {
	    return $cache_obj;
	}
    }
    return $class->new($rest, $key);
}

sub cache_store {
    my $self = shift;
    my $cache_file = $self->cache_file();
    defined($cache_file) or return; # Fail silently if cache is not configured. 
    my $rest = $self->rest_object();
    $self->unrest();
    lock_store($self => $cache_file);
    $self->rerest($rest);
}

sub search_by_email {
    my $self = shift;
    my $email = shift;
    foreach my $hit (@{$self->rest('GET', ["user/search", { username => $email, maxResults => 1000 }])}) {
	if(lc($hit->{emailAddress}) eq lc($email)) { # Case-insensitive search.
	    $self->{_content} = $hit;
	    $self->{_key} = $hit->{name};
	    $self->refresh();
	    last;
	}
    }
    defined($self->{_content}) or croak "No user found for: $email";
}

sub name {
    my $self = shift;
    return $self->{_content}->{name};
}

sub emailAddress {
    my $self = shift;
    return $self->{_content}->{emailAddress};
}

sub displayName {
    my $self = shift;
    return $self->{_content}->{displayName};
}

sub timeZone {
    my $self = shift;
    # BUG: This value seems to be the timeZone of the user
    # authenticated to run the API rather than the user we are
    # querying against. That's a bug in JIRA. Don't trust this
    # function's output!
    return $self->{_content}->{timeZone};
}

sub memberOf {
    my $self = shift;
    my $test_group = shift;
    $self->refresh() unless(defined($self->{_content}->{groups}));
    foreach my $group (@{$self->{_content}->{groups}->{items}}) {
	return 1 if $group->{name} eq $test_group;
    }
    return undef;
}

sub active {
    my $self = shift;
    return $self->{_content}->{active} ? 1 : undef;
}

sub assignable {
    my $self = shift;
    my $issue_or_project_or_key = shift;
    my $issue;
    my $project;
    if(ref($issue_or_project_or_key)) {
	$issue = $issue_or_project_or_key->key();
    } elsif($issue_or_project_or_key =~ /^[A-Z]+$/) {
	$project = $issue_or_project_or_key;
    } elsif($issue_or_project_or_key =~ /^[A-Z]+\-[0-9]+$/) {
	$issue = $issue_or_project_or_key;
    }

    my $users = $self->rest('GET', ['user/assignable/search', {username => $self->name(), project => $project, issueKey => $issue}]);
    if(defined($users) and scalar(@$users) > 0) {
	foreach my $user (@$users) {
	    if($user->{name} eq $self->key()) {
		return 1;
	    }
	}
    }
    return undef;
}

sub avatarUrl {
    my $self = shift;
    my $size = shift;

    my $area;
    if(defined($size)) {
	if($size =~ m/^[0-9]+$/) {
	    $size = "${size}x${size}";
	}
	my($w,$h) = split(/x/, $size);
	$area = $w*$h;
    }

    my @biggness = ();
    foreach my $avail_size (keys %{$self->{_content}->{avatarUrls}}) {
	my($w,$h) = split(/x/, $avail_size);
	my $avail_area = $w*$h;
	push(@biggness, [$avail_area, $avail_size]);
    }
    @biggness = sort {$b->[0] <=> $a->[0]} @biggness;
    if(not defined($area)) {
	$size=$biggness[0]->[1];
    } else {
	$size = undef;
	foreach my $avail_size (@biggness) {
	    if($avail_size->[0] <= $area) {
		$size = $avail_size->[1];
	    }
	}
    }
    $size = $biggness[-1]->[1] unless defined($size);

    return $self->{_content}->{avatarUrls}->{$size};
}

1;

__END__
