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



# Multiple Plots
