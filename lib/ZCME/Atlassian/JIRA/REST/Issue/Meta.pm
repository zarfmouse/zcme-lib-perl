# -*- Perl -*-

use strict;
use warnings;
use v5.10;

package ZCME::Atlassian::JIRA::REST::Issue::Meta;
use base qw(ZCME::REST::Object);
use Scalar::Util qw(looks_like_number);
use Data::Dumper qw(Dumper);
use Carp qw(carp croak confess);

use ZCME::Date;

our $VERBOSE = 0;
our $DRY_RUN = 0;
our @VALUE_KEYS = qw(name value id key);

sub new {
    my $class = shift;
    my $self=$class->SUPER::new(shift);
    my $key_or_content = shift;

    if(ref($key_or_content) eq 'HASH') {
	if(exists $key_or_content->{fields}) {
	    # CACHED META
	    $self->{meta} = $key_or_content;
	} elsif(exists $key_or_content->{project} and exists $key_or_content->{issuetype}) {
	    # FETCH CREATEMETA
	    my $project = $key_or_content->{project};
	    my $issuetype = $key_or_content->{issuetype};
	    my $createmeta = $self->rest('GET', 
					 ['issue/createmeta', 
					  {projectKeys => $project, 
					   issuetypeNames => $issuetype, 
					   expand => 'projects.issuetypes.fields'}]);
	    confess "Didn't get a single createmeta result: ".Dumper($createmeta) 
		unless (scalar(@{$createmeta->{projects}}) == 1 and scalar(@{$createmeta->{projects}->[0]->{issuetypes}}) == 1);
	    $self->{meta} = $createmeta->{projects}->[0]->{issuetypes}->[0];
	} else {
	    confess "Invalid content: ".Dumper($key_or_content);
	}
    } else {
	# FETCH EDITMETA
	$self->{meta} = $self->rest('GET', "issue/$key_or_content/editmeta");
    }

    return $self;
}

# Convert a nested array to a flat array.
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

# Return scalars or return the scalar name attribute from a hash.
sub _valname {
    my $val = shift;
    my $type = ref($val);
    if(not $type) {
	return $val;
    } elsif($type eq 'HASH') {
	foreach my $key (@VALUE_KEYS) {
	    if(exists($val->{$key})) {
		return $val->{$key};
	    }
	}
    } else {
	confess "Don't know how to handle $type for ".Dumper($val);
    }
}

# Check for equality of scalars or lists, sensitive to numeric or alpha values.
sub _eq {
    my ($a,$b) = (shift,shift);
    unless(defined($a) and defined($b)) {
	return undef;
    }
    my $numeric = shift || (looks_like_number($a) && looks_like_number($b));
    if(ref($a) eq 'ARRAY' and ref($b) eq 'ARRAY') {
	my $equals = scalar(@$a) == scalar(@$b);
	if($equals) {
	    for(my $i=0;$i<scalar(@$a);$i++) {
		$equals &&= _eq($a->[$i], $b->[$i]);
	    }
	}
	return $equals;
    } else {
	$a = _valname($a);
	$b = _valname($b);
	return $numeric ? $a == $b : $a eq $b;
    }
}

sub fieldkey {
    my $self = shift;
    my $field_name = shift;

    my $field_key = $field_name;
    foreach my $key (keys %{$self->{meta}->{fields}}) {
	my $field = $self->{meta}->{fields}->{$key};
	if($field->{name} eq $field_name) {
	    $field_key = $key;
	    last;
	}
    }
    return $field_key;
}

sub fieldeq {
    my $self = shift;
    my $field_name = shift;
    my $val1 = shift;
    my $val2 = shift;
    if(defined($val1) and defined($val2)) {
	if($self->datetime_field($field_name)) {
	    my $s1 = ZCME::Date->new($val1)->printf("%s");
	    my $s2 = ZCME::Date->new($val2)->printf("%s");
	    return $s1 == $s2;
	} else {
	    return _eq($val1, $val2);
	}
    } elsif(not defined($val1) and not defined($val2)) {
	return 1;
    } else {
	return undef;
    }
}

sub field_exists {
    my $self = shift;
    my $key = $self->fieldkey(shift);
    return exists $self->{meta}->{fields}->{$key};
}

sub meta {
    my $self = shift;
    my $key = $self->fieldkey(shift);
    my $meta = $self->{meta}->{fields}->{$key};
    defined($meta) or confess "No meta for $key.\n";
    return $meta;
}

sub check_operation {
    my $self = shift;
    my $key = $self->fieldkey(shift);
    my $op = shift;
    my $meta = $self->meta($key);
    foreach my $allowed (@{$meta->{operations}}) {
	return 1 if($allowed eq $op);
    }
    return undef;
}

sub array_field {
    my $self = shift;
    my $key = $self->fieldkey(shift);
    my $meta = $self->meta($key);
    if($meta->{schema}->{type} eq 'array') {
	return 1;
    }
    return undef;
}

sub field_type {
    my $self = shift;
    my $key = $self->fieldkey(shift);
    my $meta = $self->meta($key);
    if($self->array_field($key)) {
	return $meta->{schema}->{items};
    } else {
	return $meta->{schema}->{type};
    }
}

sub numeric_field {
    my $self = shift;
    my $type = $self->field_type(shift);
    return $type eq 'number';
}

sub user_field {
    my $self = shift;
    my $type = $self->field_type(shift);
    return $type eq 'user';
}

sub issuelink_field {
    my $self = shift;
    my $type = $self->field_type(shift);
    return $type eq 'issuelink';
}

sub datetime_field {
    my $self = shift;
    my $type = $self->field_type(shift);
    return $type eq 'datetime';
}

sub fieldval {
    my $self = shift;
    my $key = $self->fieldkey(shift);
    my $val = shift;
    return undef unless defined($val);
    if(ref($val) eq "ARRAY") {
	@$val = map {$self->fieldval($key, $_)} @$val;
	return $val;
    } else {
	my $meta = $self->meta($key);
	my $numeric = $self->numeric_field($key);
	if(exists($meta->{allowedValues})) {
	    foreach my $allowed (@{$meta->{allowedValues}}) {
		foreach my $i (@VALUE_KEYS) {
		    if(_eq($allowed->{$i}, $val, $numeric)) {
			return $allowed;
		    }
		}
	    }
	    confess "$val not allowed for $key";
	} elsif($self->user_field($key)) {
	    return { name => $val };
	} elsif($self->issuelink_field($key)) {
	    return { key => $val };
	} elsif($self->datetime_field($key)) {
	    my $date = ZCME::Date->new($val);
	    return $date->printf("%Y-%m-%dT%H:%M:00.000%z"); 
	} elsif($self->numeric_field($key)) {
	    return $val*1.0+0.0;
	} else {
	    return $val;
	}
    }
}

sub allowed {
    my $self = shift;
    my $key = $self->fieldkey(shift);
    my $val = shift;

    if($self->array_field($key) and ref($val) eq 'ARRAY') {
	my $true = 1;
	foreach my $v (@$val) {
	    $true &&= $self->_allowed_internal($key,$v);
	}
	return $true;
    } else {
	return $self->_allowed_internal($key,$val);
    }
}

sub _allowed_internal {
    my $self = shift;
    my $key = $self->fieldkey(shift);
    my $val = shift;

    my $meta = $self->meta($key);
    my $numeric = $self->numeric_field($key);
    if(exists($meta->{allowedValues})) {
	foreach my $allowed (@{$meta->{allowedValues}}) {
	    foreach my $i (@VALUE_KEYS) {
		if(_eq($allowed->{$i}, $val, $numeric)) {
		    return 1;
		}
	    }
	}
    } else {
	if($numeric) {
	    return looks_like_number($val);
	} elsif($self->user_field($key)) {
	    my $user = $self->{_rest}->get_user($val);
	    return (defined($user) && $user->active());
	} else {
	    return 1;
	}
    }
}

1;

__END__
