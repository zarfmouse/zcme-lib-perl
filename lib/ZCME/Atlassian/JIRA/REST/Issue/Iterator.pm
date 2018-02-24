# -*- Perl -*-

use strict;
use warnings;

package ZCME::Atlassian::JIRA::REST::Issue::Iterator;
our $maxResults = 5;
our $maxCacheResults = 100;

sub new {
    my $class = shift;
    my $self = bless {}, (ref($class)||$class);
    $self->{_rest} = shift;
    $self->{_searchRequest} = shift;
    my $start_at = shift || 0;

    $self->{_searchRequest}->{maxResults} = $maxResults;

    $self->{use_cache} = defined($self->{_rest}->cache_dir()) ? 1 : undef;
    if($self->{use_cache}) {
	$self->{_searchRequest}->{fields} = ['key', 'updated'];
	$self->{_searchRequest}->{expand} = [];
	$self->{_searchRequest}->{maxResults} = $maxCacheResults;
    }

    $self->{i} = $start_at;
    $self->_get_results($self->{i});

    return $self;
}

sub _get_results {
    my $self = shift;
    my $i = shift;
    $self->{_searchRequest}->{startAt} = $i;
    $self->{_searchResults} = ZCME::REST::repeat_until_success(sub { return $self->{_rest}->rest('POST', 'search', $self->{_searchRequest}); });
    return $self;
}

sub startAt {
    my $self = shift;
    return $self->{_searchResults}->{startAt};
}

sub endAt {
    my $self = shift;
    return $self->{_searchResults}->{startAt} + scalar(@{$self->{_searchResults}->{issues}}) - 1;
}

sub total {
    my $self = shift;
    return $self->{_searchResults}->{total};
}

sub _issue_package {
    my $self = shift;
    my $pkg = __PACKAGE__;
    $pkg =~ s/\:\:Iterator$//;
    return $pkg;
}

sub index {
    my $self = shift;
    my $i = shift;
    $i >= 0 || return undef;
    $i < $self->total() || return undef;

    if($i < $self->startAt() or $i > $self->endAt()) {
	$self->_get_results($i);
    }
    my $rest_data = $self->{_searchResults}->{issues}->[$i - $self->startAt()];
    if(defined($rest_data)) {
	if($self->{use_cache}) {
	    return $self->_issue_package()->cache_retrieve($self->{_rest}, $rest_data->{key}, $rest_data->{fields}->{updated});	    
	} else {
	    return $self->_issue_package()->new($self->{_rest}, $rest_data);
	} 
    } else {
	return undef;
    }
}

sub current {
    my $self = shift;
    return $self->index($self->{i});
}

sub next {
    my $self = shift;
    my $retval = $self->current();
    $self->{i}++;
    return $retval;
}

1;

__END__
