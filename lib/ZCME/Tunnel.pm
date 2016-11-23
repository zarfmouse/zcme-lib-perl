# -*- Perl -*-

use strict;
use warnings;

package ZCME::Tunnel;

our $VERBOSE = 0;

use File::Temp qw(tmpnam);
use ZCME::HereDoc qw(here);

my %Defaults = (
    -sshport => 22,
    -type => 'local',
    );

my $Usage = here(<<"EOF");
# __PACKAGE__->new(-hostname => 'example.com',
#                  -port => 9000,
#                  -host => '192.168.1.1',
#                  -hostport => 3306);
# ssh -L {port}:{host}:{hostport} {hostname}
# 
# Other parameters:
# -sshport  The port on hostname to ssh into (default $Defaults{-sshport})
# -type     'local' for -L and 'remote' for -R (default $Defaults{-type})
# -user     The user to log in to hostname as.
# -tmpfile  The file to use for the control socket for the master SSH process.
EOF
    ;

sub new {
    my $class = shift;
    my $self = bless {@_}, (ref($class)||$class);

    foreach my $key (keys %Defaults) {
	exists $self->{$key} or $self->{$key} = $Defaults{$key};
    }

    exists $self->{-tmpfile} or $self->{-tmpfile} = tmpnam();

    foreach my $key (qw(hostname port host hostport sshport type tmpfile)) {
	exists $self->{"-$key"} or die $Usage;
    }

    my $typeflag = $self->{-type} eq 'remote' ? '-R' : '-L';

    my $sshcmd = qq(ssh -N -f -M -S $self->{-tmpfile} $typeflag $self->{-port}:$self->{-host}:$self->{-hostport} -p $self->{-sshport} $self->{-hostname});
    warn "$sshcmd\n" if $VERBOSE;
    if(exists $self->{-user}) {
	$sshcmd .= " -l $self->{-user}";
    }
    system($sshcmd)==0 or die "'$sshcmd' failed: $?";

    return $self;
}

sub DESTROY {
    my $self = shift;
    my $sshcmd = qq(ssh -O exit -S $self->{-tmpfile} localhost 2> /dev/null);
    warn "$sshcmd\n" if $VERBOSE;
    system($sshcmd)==0 or die "'$sshcmd' failed: $?";
};

1;

__END__
