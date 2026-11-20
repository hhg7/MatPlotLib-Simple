consider this code:

bar(
	data => {
		KDC => {
			authorized => 56,
			staffed    => 12
		}
	},
	label       => [ 'staffed', 'authorized'],
	stacked     => true,
	output_file => 'pdn.authorized.svg'
);
"staffed" shows on top no matter what, and I'd like it to be on the bottom. Further, label has no effect at all
