# -*- Perl -*-

use strict;
use warnings;
use v5.10;

package ZCME::Atlassian::JIRA::REST::Issue::New;
use base qw(ZCME::REST::Object);

use ZCME::Atlassian::JIRA::REST::Issue::Meta;

use Carp qw(croak);
use JSON qw(encode_json);

our $VERBOSE = 0;
our $DRY_RUN = 0;

sub new {
    my $class = shift;
    my $self=$class->SUPER::new(shift);
    $self->{_init} = shift;

    my $project = $self->{_init}->{project};
    my $issuetype = $self->{_init}->{issuetype};

    defined($project) && defined($issuetype) 
	or croak "Must provide a project and issuetype";

    foreach my $key (keys %{$self->{_init}}) {
	$self->set($key, $self->{_init}->{$key});
    }

    return $self;
}

#
# CREATEMETA
#

sub reset_meta { 
    my $self = shift;
    delete $self->{meta};
}

sub createmeta {
    my $self = shift;
    unless(exists($self->{meta})) {
	my $pkg = __PACKAGE__;
	$pkg =~ s/::New$/::Meta/;
	$self->{meta} = $pkg->new($self->{_rest}, $self->{_init});
    }
    return $self->{meta};
}

sub fieldval {
    my $self = shift;
    return $self->createmeta()->fieldval(@_);
}

sub allowed {
    my $self = shift;
    return $self->createmeta()->allowed(@_);
}

sub fieldkey {
    my $self = shift;
    return $self->createmeta()->fieldkey(@_);
}

sub field_exists {
    my $self = shift;
    return $self->createmeta()->field_exists(@_);
}

sub set {
    my $self = shift;
    my $key = $self->fieldkey(shift);
    my $val = $self->fieldval($key, shift);
    if(defined($val)) {
	$self->{fields}->{fields}->{$key} = $val;
    }
}

sub save {
    my $self = shift;
    if($VERBOSE) {
	warn "Creating issue:\n";
        foreach my $key (keys %{$self->{fields}->{fields}}) {
            my $val = $self->{fields}->{fields}->{$key};
            my $key_name = $self->{_rest}->fieldname($key);
	    my $val_str = $val;
	    if(ref($val)) {
		$val_str = encode_json($val);
	    }
            warn "\t$key ($key_name): $val_str\n";
        }
    }
    if($DRY_RUN) {
	return undef;
    } else {
	my $issue = $self->rest('POST', 'issue', $self->{fields});
	my $key = $issue->{key};
	return $self->{_rest}->get_issue($key);
    }
}

1;

__END__


