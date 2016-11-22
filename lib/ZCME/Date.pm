# -*- Perl -*-
use strict;
use warnings;

package ZCME::Date;

use Date::Manip::Date;
use POSIX qw(strftime);
use File::Basename qw(dirname);
use Carp qw(croak carp confess);
use Scalar::Util qw(blessed);
use Data::Dumper qw(Dumper);

my $lib = dirname(__FILE__);
$lib =~ s[/lib/.*$][/lib];
our $config = "$lib/ZCME/Date/DateManip.conf";

sub _args {
    my @args = @_;
    for(my $i=0;$i<scalar(@args);$i++) {
	if(ref($args[$i]) eq __PACKAGE__) {
	    $args[$i] = $args[$i]->{date};
	}
    }
    return @args;
}

sub new {
    my $class = shift;
    my $self = bless {}, (ref($class)||$class);
    if(blessed($_[0]) and ($_[0]->isa(__PACKAGE__) or $_[0]->can('printf'))) {
	$self->{date} = Date::Manip::Date->new($_[0]->printf("%O"));
    } else {
	$self->{date} = Date::Manip::Date->new(_args(@_));
    }
    $self->{date}->config("ConfigFile" => $config);
    return $self;
}

sub mysql_datetime {
    my $self=shift;
    return $self->printf("%Y-%m-%d %H:%M:%S");
}

sub mysql_date {
    my $self=shift;
    return $self->printf("%Y-%m-%d");
}

sub jqlt_date {
    my $self=shift;
    return $self->printf("%Y/%m/%d");
}

# NOTE: Date::Manip::Date does not allow subclassing so we have to
# fake it like this.
sub AUTOLOAD {
    my $self = shift;
    use vars qw($AUTOLOAD);
    my $method = $AUTOLOAD;
    my $this_package = __PACKAGE__;
    $method =~ s/^${this_package}:://;
    unless(defined($self->{date})) {
	confess "Can't do $method because self has no {date}: ".Dumper($self);
    }
    # NOTE: If Date::Manip::Date uses any AUTOLOAD methods this can()
    # will fail.
    if($self->{date}->can($method)) {
	my $ret = $self->{date}->$method(_args(@_));
	if(ref($ret) and $ret->isa('Date::Manip::Date')) {
	    $ret = $self->new($ret);
	}
	return $ret;
    } elsif($method eq 'DESTROY') {
	return undef;
    } else {
	croak "Couldn't find $method.";
    }
}

1;
