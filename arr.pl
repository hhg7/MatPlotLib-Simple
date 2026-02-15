#!/usr/bin/env perl

use 5.042;
no source::encoding;
use warnings FATAL => 'all';
use autodie ':default';
use Matplotlib::Simple;
use File::Temp;
use JSON::MaybeXS;
use File::Temp;
use MIME::Base64;

my %data = (
	'Product A'  => 10,
	"Product\nB" => 20, # <--- This newline breaks the Python script
);

bar({
	'output.file' => '/tmp/newline_fail.svg',
	data          => \%data,
	title         => 'Broken Chart',
});

plt({
    'output.file' => 'test.png',
    'plot.type'   => 'bar',
    data          => \%data,
    # The backslash makes Python think we are escaping the closing quote
    title         => 'C:\Users\Name\'', 
});

=sub write_data {
	my ($args) = @_;
	my $current_sub = ( split( /::/, ( caller(0) )[3] ) )[-1];
	if ( ref $args ne 'HASH' ) {
	  die "args must be given as a hash ref, e.g. \"$current_sub({ data => ... })\"";
	}
	my @reqd_args = (
	  'data', # args to original function (scalar, hashref, or arrayref)
	  'fh',   # file handle
	  'name'  # python variable name
	);
	my @undef_args = grep { not defined $args->{$_} } @reqd_args;
	if (scalar @undef_args > 0) {
	  p @undef_args;
	  die "the above args are required for $current_sub, but weren't defined";
	}
	# 1. Create the JSON Encoder
	# allow_nonref: allows scalars (strings/numbers) to be encoded
	my $json_encoder = JSON::MaybeXS->new->utf8->allow_nonref;
	# 2. Serialize Perl Data -> JSON String
	# We pass the data directly. JSON::MaybeXS handles refs and scalars automatically.
	my $json_string = $json_encoder->encode($args->{data});
	# 3. Base64 Encode the JSON String
	# We encode the STRING, not the reference.
	my $b64_data = encode_base64($json_string, ''); 
	# 4. Generate Python Code
	my $fh = $args->{fh};
	my $var_name = $args->{name};
	# We only print imports if we haven't already (simple check, optional optimization)
	# For safety in this snippet, we print them every time or assume they are at the top.
	# Here is a block that is safe to repeat or place once:
	say $fh 'import base64, json';
	# Assign the b64 string to a temp python variable
	say $fh "$args->{name}_b64 = '$b64_data'";
	# Decode b64 -> bytes -> utf8 string -> json load -> python object
	say $fh "$args->{name} = json.loads(base64.b64decode(${var_name}_b64).decode('utf-8'))";
	# Debug print in Python to verify
	say $fh "print(f'Decoded \"$args->{name}\": {${var_name}}')";
}

my $fh = File::Temp->new( DIR => '/tmp', SUFFIX => '.py', UNLINK => 0);
say $fh->filename;
write_data({
	data => { A => 1, B => 2},
	fh   => $fh,
	name => 'vals'
});
write_data({
	data => ['A'..'Z', '", = \\'],
	fh   => $fh,
	name => 'labels'
});
write_data({
	data => 'string',
	fh   => $fh,
	name => 'string'
});
close $fh;
say __LINE__;
say $fh->filename;
my $r = execute('python ' . $fh->filename, 'all');
p $r;
# 3. Generate Python code that decodes the data
=plt({
	plots => [
		{
			color        => {
				A => 'red', B => 'green', C => 'blue'
			},
			data => {
				A => 1, B => 2, C => 3
			},
			'plot.type'   => 'bar'
		},
		{
			color        => {
				A => 'red', B => 'green', C => 'blue'
			},
			data => {
				A => 1, B => 2, C => 3
			},
			'plot.type'   => 'barh'
		},
	],
	ncols         => 2,
	'output.file' => '/tmp/key.colors.bar.svg',
});
