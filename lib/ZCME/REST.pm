# -*- Perl -*-

package ZCME::REST;

use strict;
use warnings;

use LWP::UserAgent;
use HTTP::Cookies;
use JSON qw(decode_json encode_json);
use XML::Simple qw(:strict);
use CGI qw(escape);
use Data::Dumper qw(Dumper);
use Carp qw(carp croak confess cluck);
use Digest::MD5 qw(md5_hex);
use Socket qw($CRLF);

our $VERBOSE = 0;

sub new {
    my $class = shift;
    my $self = bless {}, (ref($class)||$class);

    return $self;
}

sub decorate_request { }
sub base_url { die "abstract"; }
sub format { return 'json'; }
sub response_format { return undef; }

sub _get_ua {
    my $self = shift;
    if(not defined($self->{_FTLua})) {
	my $ua = LWP::UserAgent->new;
	$ua->agent("ZCME::REST.pm/0.1");
	my $cookies = HTTP::Cookies->new({});
	$ua->cookie_jar($cookies);
	$self->{_FTLua} = $ua;
    }
    return $self->{_FTLua};
}

sub _querystring_from_ref {
    my $self = shift;
    my $query = shift;
    my @pairs = ();
    if(ref($query) eq 'HASH') {
	# Query is a hash mapping keys to values. Values might
	# be arrays of values for the key.
	foreach my $key (keys %$query) {
	    if(ref($query->{$key}) eq 'ARRAY') {
		foreach my $value (@{$query->{$key}}) {
		    push(@pairs, [$key, $value]);
		}
	    } elsif(defined($query->{$key})) {
		push(@pairs, [$key, $query->{$key}]);
	    }
	}
    } elsif(ref($query) eq 'ARRAY') {
	foreach my $pair (@$query) {
	    if(ref($pair->[1]) eq 'ARRAY') {
		foreach my $value (@{$pair->[1]}) {
		    push(@pairs, [$pair->[0], $value]);
		}
	    } else {
		push(@pairs, [$pair->[0], $pair->[1]]);
	    }
	}
    } else {
	die '$query must be a ref of type HASH or ARRAY';
    }
    return join('&', 
		map {CGI::escape($_->[0]).'='.CGI::escape($_->[1])} @pairs);
}

sub repeat_until_success {
    my $sub = shift;
    my @retval;
    my $i;
    for($i=0;$i<10;$i++) {
	eval {
	    @retval = &$sub();
	};
	if($@ and $@ =~ /(?:Unable to connect)|(?:Connection timed out)|(?:Can\'t connect)|(?:Server closed connection without sending any data back)|(?:Network is unreachable)|(?:read timeout)|(?:502 Proxy Error)|(?:Could not save: there was a problem flushing the hibernate transaction)|(?:java\.net\.SocketTimeoutException)|(?:429 Too Many Requests)/) {
	    warn "Repeating operation in $i seconds after error:\n$@" if $VERBOSE;
	    sleep $i+rand($i);
	    next;
	}
	last;
    }
    if($@) {
	unless($@ =~ /Version must be incremented on update\. Current version is:/) {
	    die "Failed after $i tries.\n$@";
	} 
    }

    if(wantarray) {
	return @retval;
    } else {
	return $retval[0];
    }
}

sub _headers_to_array {
    my $headers = shift;
    unless(defined($headers)) {
	return [];
    }
    if(ref($headers) eq 'HASH') {
	$headers = [ map { [ $_ => $headers->{$_} ] } keys %$headers ];
    }
    return $headers;
}

##
# -method - GET|POST|PUT|DELETE
# -format - json|xml|undef
# -response-format - json|xml|undef
# -uri
# -body-query
# -uri-query
## 
sub lwp_request {
    my $self = shift; 
    my %params = scalar(@_) == 1 ? (-uri => $_[0]) : @_;
    my $method = $params{-method} || 'GET';
    my $format = $params{-type};
    my $response_format = $params{-response_type};
    my $uri = $params{-uri};
    my $body_query = $params{-body_query};
    my $uri_query = $params{-uri_query};
    my $repeat = $params{-repeat} || $method eq 'GET';
    my $headers = _headers_to_array($params{-headers});
    my $parts = $params{-parts};
    my $multipart = $params{-multipart} || 'related';
    my $response_file = $params{-response_file};

    my $ua = $self->_get_ua();

    my $req = HTTP::Request->new();
    $req->method($method);

    foreach my $header_pair (@$headers) {
	$req->header($header_pair->[0] => $header_pair->[1]);
    }
    
    if(defined($uri_query)) {
	my $qs = $self->_querystring_from_ref($uri_query);
	if(defined($qs) and length($qs)) {
	    $uri .= "?$qs";
	}
    }
    $req->uri($uri);

    if(defined($body_query)) {
	if(defined($format) and $format eq 'json') {
	    $req->content_type("application/json; charset=UTF-8");
	    $req->content(encode_json($body_query));
	} else {
	    $req->content_type('application/x-www-form-urlencoded');
	    my $qs = $self->_querystring_from_ref($body_query);
	    if(defined($qs) and length($qs)) {
		$req->content($qs);
	    }
	}
    } elsif(defined($parts)) {
	my $boundary = md5_hex(rand());
	my $body;
	foreach my $part (@$parts) {
	    $body .= "$CRLF--$boundary$CRLF";
	    my $headers = _headers_to_array($part->{headers});
	    foreach my $header_pair (@$headers) {
		$body .= "$header_pair->[0]: $header_pair->[1]$CRLF";
	    }
	    $body .= $CRLF;
	    $body .= $part->{body};
	}
	$body .= "$CRLF--$boundary--$CRLF";
	$req->content_type(qq(multipart/$multipart; boundary="$boundary"));
	utf8::encode($body);
	$req->content($body);
    }

    $self->decorate_request($req);
    warn $req->as_string()."\n" if $VERBOSE;

    my $res;
    my $content = &repeat_until_success( 
	sub {
	    $res = $ua->request($req, $response_file);
	    if ($res->is_success) {
		warn $res->as_string()."\n" if $VERBOSE;
		return $res->decoded_content;
	    } else {
		my $error_output = "Failed Request.\n";
		$error_output .= $req->as_string();
		$error_output .= $res->as_string();
		confess $error_output;
	    }
	});


    unless(defined($response_format)) {
	my $content_type = $res->header('Content-type');
	if($content_type =~ m/json/) {
	    $response_format = 'json';
	} elsif($content_type =~ m/xml/) {
	    $response_format = 'xml';
	} elsif($content_type =~ m/plain/) {
	    $response_format = 'text';	    
	}
    }

    if(defined($content) and length($content)) {
	if(defined($response_format)) {
	    if($response_format eq 'json') {
		my $retval;
		eval {
		    $retval = decode_json($content);
		};
		if($@) {
		    my $error = "JSON Decoding Failure: $@\n\n";
		    $error .= $req->as_string();		    
		    die $error;
		}
		return $retval;
	    } elsif($response_format eq 'xml') {
		my $xs = XML::Simple->new(ForceArray => 1, KeyAttr=>[]);
		return $xs->XMLin($content);
	    } elsif($response_format eq 'text') {
		return $content;
	    } else {
		croak "Invalid response format: $response_format";
	    }
	} else {
	    return $content;
	}
    } else {
	return undef;
    }
}

sub rest {
    my $self = shift;
    my $method = shift;
    my $path = shift;
    my $data = shift;
    my $format = shift || $self->format();
    my $response_format = shift || $self->response_format();

    my $uri_query;
    if(ref($path) eq 'ARRAY') {
	($path, $uri_query) = @$path;
    }

    my $content = $self->lwp_request(
	-uri => $self->base_url()."/$path",
	-method => $method,
	-type => $format,
	-response_type => $response_format,
	-body_query => $data,
	-uri_query => $uri_query,
	);

    return $content;
}

1;

__END__
