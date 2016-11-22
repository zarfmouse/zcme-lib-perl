# -*- Perl -*-

use strict;
use warnings;
use v5.10;

package ZCME::Atlassian::JIRA::REST::Issue::Attachment;
use base qw(ZCME::REST::Object);
use Data::Dumper qw(Dumper);
use Carp qw(carp croak);

sub new {
    my $class = shift;
    my $self=$class->SUPER::new(shift);
    my $key_or_content = shift;
    if(ref($key_or_content) eq 'HASH') {
	# Construct from an existing JSON blob.
	$self->{_content} = $key_or_content;
	$self->{_key} = $self->{_content}->{id};
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
    $self->{_content} = $self->rest('GET', "attachment/$self->{_key}");    
}

sub filename {
    my $self = shift;
    return $self->{_content}->{filename};
}

sub mimeType {
    my $self = shift;
    return $self->{_content}->{mimeType};
}

sub size {
    my $self = shift;
    return $self->{_content}->{size};
}

sub fetch {
    my $self = shift;
    my $filename = shift;
    my $url = $self->{_content}->{content};
    return $self->rest_object()->lwp_request( -uri => $url, -response_file => $filename );
}

sub delete {
    my $self = shift;
    $self->rest('DELETE', "attachment/$self->{_key}");
}

1;

__END__


