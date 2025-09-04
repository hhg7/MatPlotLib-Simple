# Synopsis

Take a data structure in Perl, and automatically write a Python3 script using matplotlib to generate an image.  The Python3 script is saved in `/tmp`, to be edited at the user's discretion.
Simplest use case:
```
use Matplotlib::Simple 'plot';
plot({
	'output.filename'			=> 'output.images/single.barplot.png',
	data	=> { # simple hash
		Fri => 76, Mon	=> 73, Sat => 26, Sun => 11, Thu	=> 94, Tue	=> 93, Wed	=> 77
	},
	'plot.type'	=> 'bar',
	xlabel		=> '# of Days',
	ylabel		=> 'Count',
	title		=> 'Customer Calls by Days'
});
```
where `xlabel`, `ylabel`, `title`, etc. are axis methods in matplotlib itself. `plot.type`, `data`, `input.file` are all specific to `MatPlotLib::Simple`.

<img width="651" height="491" alt="single barplot" src="https://github.com/user-attachments/assets/f4abf891-47f9-45b0-a9c4-96934fcead24" />

# Plot Types

`bar`, `barh`, `boxplot`, `hexbin`, `hist`, `pie`, `plot`, `scatter`, `violinplot` all match the methods in matplotlib itself.

# Single Plots
Consider the following helper subroutines to generate data to plot:

```
sub linspace { # mostly written by Grok
	my ($start, $stop, $num, $endpoint) = @_; # endpoint means include $stop
	$num = defined $num ? int($num) : 50; # Default to 50 points
	$endpoint = defined $endpoint ? $endpoint : 1; # Default to include endpoint
	return () if $num < 0; # Return empty array for invalid num
	return ($start) if $num == 1; # Return single value if num is 1
	my (@result, $step);

	if ($endpoint) {
	  $step = ($stop - $start) / ($num - 1) if $num > 1;
	  for my $i (0 .. $num - 1) {
		   $result[$i] = $start + $i * $step;
	  }
	} else {
	  $step = ($stop - $start) / $num;
	  for my $i (0 .. $num - 1) {
		   $result[$i] = $start + $i * $step;
	  }
	}
	return @result;
}

sub generate_normal_dist {
	my ($mean, $std_dev, $size) = @_;
	$size = defined $size ? int $size : 100; # default to 100 points
	my @numbers;
	for (1 .. int($size / 2) + 1) {# Box-Muller transform
		my $u1 = rand();
		my $u2 = rand();
		my $z0 = sqrt(-2.0 * log($u1)) * cos(2.0 * 3.141592653589793 * $u2);
		my $z1 = sqrt(-2.0 * log($u1)) * sin(2.0 * 3.141592653589793 * $u2); # Scale and shift to match mean and std_dev
		push @numbers, ($z0 * $std_dev + $mean, $z1 * $std_dev + $mean);
	} # Trim to exact size if needed
	@numbers = @numbers[0 .. $size - 1] if @numbers > $size;
	@numbers = map {sprintf '%.1f', $_} @numbers;
	return \@numbers;
}
sub rand_between {
	my ($min, $max) = @_;
	return $min + rand($max - $min)
}
```
## Barplot/bar/barh
```
use Matplotlib::Simple 'plot';
plot({
	'output.filename'			=> 'output.images/single.barplot.png',
	data	=> { # simple hash
		Fri => 76, Mon	=> 73, Sat => 26, Sun => 11, Thu	=> 94, Tue	=> 93, Wed	=> 77
	},
	'plot.type'	=> 'bar',
	xlabel		=> '# of Days',
	ylabel		=> 'Count',
	title		=> 'Customer Calls by Days'
});
```
where `xlabel`, `ylabel`, `title`, etc. are axis methods in matplotlib itself. `plot.type`, `data`, `input.file` are all specific to `MatPlotLib::Simple`.
<img width="651" height="491" alt="single barplot" src="https://github.com/user-attachments/assets/eae009a8-5571-4608-abdb-1016e3cff5fd" />
### Options
| Option | Description | Example |
| -------- | ------- | ------- 
|color| :mpltype:`color` or list of :mpltype:`color`, optional; The colors of the bar faces. This is an alias for *facecolor*. If both are given, *facecolor* takes precedence # if entering multiple colors, quoting isn't needed|`color => ['red', 'orange', 'yellow', 'green', 'blue', 'indigo', 'fuchsia'],` or a single color for all bars `color => 'red'`
|edgecolor| :mpltype:`color` or list of :mpltype:`color`, optional; The colors of the bar edges|`edgecolor		=> 'black'`
|key.order|  define the keys in an order (an array reference)|`'key.order'		=> ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'],`
|linewidth| float or array, optional; Width of the bar edge(s). If 0, don't draw edges. Only does anything with defined `edgecolor`|`linewidth => 2,`
|log| bool, default: False; If *True*, set the y-axis to be log scale.|`log = 'True',`
|stacked| stack the groups on top of one another; default 0 = off|`stacked	=> 1,`
|width| float or array, default: 0.8; The width(s) of the bars.|
|xerr| float or array-like of shape(N,) or shape(2, N), optional. If not *None*, add horizontal / vertical errorbars to the bar tips. The values are +/- sizes relative to the data:        - scalar: symmetric +/- values for all bars #        - shape(N,): symmetric +/- values for each bar #        - shape(2, N): Separate - and + values for each bar. First row #          contains the lower errors, the second row contains the upper #          errors. #        - *None*: No errorbar. (Default)|
|yerr|same as xerr, but better with bar|
 
an example of multiple plots, showing many options:

```
plot({
	'input.file'		=> $tmp_filename,
	execute				=> 0,
	'output.filename'	=> 'output.images/barplots.png',
	plots					=> [
		{ # simple plot
			data	=> { # simple hash
				Fri => 76, Mon	=> 73, Sat => 26, Sun => 11, Thu	=> 94, Tue	=> 93, Wed	=> 77
			},
			'plot.type'	=> 'bar',
			'key.order'		=> ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'],
			suptitle			=> 'Types of Plots', # applies to all
			color				=> ['red', 'orange', 'yellow', 'green', 'blue', 'indigo', 'fuchsia'],
			edgecolor		=> 'black',
			set_figwidth	=> 40/1.5, # applies to all plots
			set_figheight	=> 30/2, # applies to all plots
			title				=> 'bar: Rejections During Job Search',
			xlabel			=> 'Day of the Week',
			ylabel			=> 'No. of Rejections'
		},
		{ # grouped bar plot
			'plot.type'	=> 'bar',
			data	=> {
				1941 => {
				  UK      => 6.6,
				  US      => 6.2,
				  USSR    => 17.8,
				  Germany => 26.6
				},
				1942 => {
				  UK      => 7.6,
				  US      => 26.4,
				  USSR    => 19.2,
				  Germany => 29.7
				},
				1943 => {
				  UK      => 7.9,
				  US      => 61.4,
				  USSR    => 22.5,
				  Germany => 34.9
				},
				1944 => {
				  UK      => 7.4,
				  US      => 80.5,
				  USSR    => 27.0,
				  Germany => 31.4
				},
				1945 => {
				  UK      => 5.4,
				  US      => 83.1,
				  USSR    => 25.5,
				  Germany => 11.2 #Rapid decrease due to war's end	
				},
			},
			stacked	=> 0,
			title		=> 'Hash of Hash Grouped Unstacked Barplot',
			width		=> 0.23,
			xlabel	=> 'r"$\it{anno}$ $\it{domini}$"', # italic
			ylabel	=> 'Military Expenditure (Billions of $)'
		},
		{ # grouped bar plot
			'plot.type'	=> 'bar',
			data	=> {
				1941 => {
				  UK      => 6.6,
				  US      => 6.2,
				  USSR    => 17.8,
				  Germany => 26.6
				},
				1942 => {
				  UK      => 7.6,
				  US      => 26.4,
				  USSR    => 19.2,
				  Germany => 29.7
				},
				1943 => {
				  UK      => 7.9,
				  US      => 61.4,
				  USSR    => 22.5,
				  Germany => 34.9
				},
				1944 => {
				  UK      => 7.4,
				  US      => 80.5,
				  USSR    => 27.0,
				  Germany => 31.4
				},
				1945 => {
				  UK      => 5.4,
				  US      => 83.1,
				  USSR    => 25.5,
				  Germany => 11.2 #Rapid decrease due to war's end	
				},
			},
			stacked	=> 1,
			title		=> 'Hash of Hash Grouped Stacked Barplot',
			xlabel	=> 'r"$\it{anno}$ $\it{domini}$"', # italic
			ylabel	=> 'Military Expenditure (Billions of $)'
		},
		{# grouped barplot: arrays indicate Union, Confederate which must be specified in options hash
			data					=> { # 4th plot: arrays indicate Union, Confederate which must be specified in options hash
			 'Antietam'				=> [ 12400, 10300 ],
			 'Gettysburg'			=> [ 23000, 28000 ],
			 'Chickamauga'			=> [ 16000, 18000 ],
			 'Chancellorsville'	=> [ 17000, 13000 ],
			 'Wilderness'			=> [ 17500, 11000 ],
			 'Spotsylvania'		=> [ 18000, 12000 ],
			 'Cold Harbor'			=> [ 12000, 5000  ],
			 'Shiloh'				=> [ 13000, 10700 ],
			 'Second Bull Run'	=> [ 10000, 8000  ],
			 'Fredericksburg'		=> [ 12600, 5300  ],
			},
			'plot.type'	=> 'barh',
			color		=>	['blue', 'gray'], # colors match indices of data arrays
			label		=> ['North', 'South'], # colors match indices of data arrays
			xlabel	=> 'Casualties',
			ylabel	=> 'Battle',
			title		=> 'barh: hash of array'
		},
		{ # 5th plot: barplot with groups
			data	=> {
				1942 => [ 109867,  310000, 7700000 ], # US, Japan, USSR
				1943 => [ 221111,  440000, 9000000 ],
				1944 => [ 318584,  610000, 7000000 ],
				1945 => [ 318929, 1060000, 3000000 ],
			},
			color		=> ['blue', 'pink', 'red'], # colors match indices of data arrays
			label		=> ['USA', 'Japan', 'USSR'], # colors match indices of data arrays
			'log'		=> 1,
			title		=> 'grouped bar: Casualties in WWII',
			ylabel	=> 'Casualties',
			'plot.type'	=> 'bar'
		},	
		{ # nuclear weapons barplot
			'plot.type'		=> 'bar',
			data => {
				'USA'				=> 5277, # FAS Estimate
				'Russia'			=> 5449, # FAS Estimate
				'UK'				=> 225, # Consistent estimate
				'France'			=> 290, # Consistent estimate
				'China'			=> 600, # FAS Estimate
				'India'			=> 180, # FAS Estimate
				'Pakistan'		=> 130, # FAS Estimate
				'Israel'			=> 90, # FAS Estimate
				'North Korea'	=> 50, # FAS Estimate
			},
			title		=> 'Simple hash for barchart with yerr',
			xlabel	=> 'Country',
			yerr						=> {
				'USA'				=> [15,29],
				'Russia'			=> [199,1000],
				'UK'				=> [15,19],
				'France'			=> [19,29],
				'China'			=> [200,159],
				'India'			=> [15,25],
				'Pakistan'		=> [15,49],
				'Israel'			=> [90,50],
				'North Korea'	=> [10,20],
			},
			ylabel	=> '# of Nuclear Warheads',
			'log'						=> 'True', #	linewidth				=> 1,
		}
	],
	ncols	=> 3,
	nrows	=> 4
});
```
which produces the plot:

<img width="2678" height="849" alt="barplots" src="https://github.com/user-attachments/assets/648f53cd-c2de-4444-b45b-89e608c47967" />

## hexbin
```
plot({
	data	=> {
		E	=> generate_normal_dist(100, 15, 3*210),
		B	=> generate_normal_dist(85, 15, 3*210)
	},
	'output.filename'	=> 'output.images/single.hexbin.png',
	'plot.type'	=> 'hexbin',
	set_figwidth => 12,
	title			=> 'Simple Hexbin',
});
```
which makes the following plot:
<img width="1208" height="491" alt="single hexbin" src="https://github.com/user-attachments/assets/129c41cd-2d7d-43de-978a-2b9c441b8939" />

# Advanced
