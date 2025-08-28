Simplest use case:

Making a bar plot from a hash:
```
plot({
	'output.filename'			=> 'svg/single.barplot.svg',
	data	=> { # simple hash
		Fri => 76, Mon	=> 73, Sat => 26, Sun => 11, Thu	=> 94, Tue	=> 93, Wed	=> 77
	},
	'plot.type'	=> 'bar',
});
```<img width="651" height="491" alt="single barplot" src="https://github.com/user-attachments/assets/05f164d4-f330-41ab-b04f-1d5ac786b58b" />
