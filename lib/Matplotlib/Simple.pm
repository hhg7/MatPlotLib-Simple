# ABSTRACT: Access Matplotlib from Perl; providing consistent user interface between different plot types
use strict;
use feature 'say';
use warnings FATAL => 'all';

package Matplotlib::Simple;
require 5.010;
our $VERSION = 0.32;
use Scalar::Util 'looks_like_number';
use List::Util qw(max sum min);
use Cwd 'getcwd';
use File::Spec;
use File::Temp;
use DDP { output => 'STDOUT', array_max => 10, show_memsize => 1 };
use Devel::Confess 'color';
use FindBin '$RealScript';
use Exporter 'import';
use Capture::Tiny 'capture';
use JSON::MaybeXS;
use MIME::Base64;
our @EXPORT = qw(plt bar barh boxplot colored_table hexbin hist hist2d imshow pie plot scatter venn_proportional_area violinplot violin wide);
use Encode ();
our @EXPORT_OK = @EXPORT;

my @ax_methods = (
 'ArtistList',     'add_child_axes', 'add_collection', 'add_container',
 'add_image',      'add_line', 'add_patch', 'add_table', 'apply_aspect',
 'autoscale_view', 'axison',   'bxp', 'callbacks', 'can_pan', 'can_zoom',
 'child_axes', 'collections', 'containers', 'contains_point', 'dataLim',
 'drag_pan',   'end_pan',     'fmt_xdata',  'fmt_ydata',      'format_coord',
 'format_xdata', 'format_ydata','hexbin', 'hist', 'hist2d', 'hlines',
 'ignore_existing_data_limits', 'in_axes',    'indicate_inset',
'indicate_inset_zoom',         'inset_axes', 'invert_xaxis', 'invert_yaxis',
 'label_outer', 'legend_', 'name', 'pcolorfast', 'redraw_in_frame', 'relim',
 'reset_position',	'scatter', 'secondary_xaxis', 'secondary_yaxis', 'set_adjustable',
 'set_anchor', 'set_aspect', 'set_autoscale_on', 'set_autoscalex_on', 'set_autoscaley_on',
 'set_axes_locator', 'set_axis_off',    'set_axis_on',   'set_axisbelow',
 'set_box_aspect',   'set_fc',          'set_forward_navigation_events',
 'set_frame_on',     'set_navigate', 'set_navigate_mode',
 'set_position',     'set_prop_cycle',  'set_rasterization_zorder',
 'set_subplotspec',  'set_title',       'set_xbound', 'set_xlabel',
 'set_xlim', # ax.set_xlim(left, right), or ax.set_xlim(right = 180)
 'set_xmargin', 'set_xscale', 'set_xticklabels', 'set_xticks', 'set_ybound',
 'set_ylabel',  'set_ylim',   'set_ymargin', 'set_yscale', 'set_yticklabels',
 'set_yticks',  'sharex',     'sharey',      'spines', 'start_pan', 'tables',
 'text', 'tick_params', 'ticklabel_format', 'titleOffsetTrans', 'transAxes', 'transData', 'transLimits',
 'transScale', 'update_datalim', 'use_sticky_edges', 'viewLim', 'vlines', 'violin',
 'xaxis',      'xaxis_date',     'xaxis_inverted',   'yaxis',   'yaxis_date',
 'yaxis_inverted'
);
my @fig_methods = (
	'add_artist', 'add_axes', 'add_axobserver', 'add_callback', 'add_gridspec',
	'add_subfigure', 'add_subplot',   'align_labels', 'align_titles',
	'align_xlabels', 'align_ylabels', 'artists',	'autofmt_xdate', #'axes', # same as plt
	'bbox', 'bbox_inches', 'canvas', 'clear', 'clf', 'clipbox',
	'colorbar',  # same name as in plt, have to use on case-by-case
	'contains',           'convert_xunits', 'convert_yunits', 'delaxes', 'dpi',
	'dpi_scale_trans',    'draw', 'draw_artist', 'draw_without_rendering',
	'figbbox',            'figimage',    # 'figure', 'findobj',
	'format_cursor_data', 'frameon', 'have_units', 'images',    'is_transform_set',    # 'legend',	 legends',
	'lines',      'mouseover', 'number', 'patch', 'patches', 'pchanged', 'pick',
	'pickable',   'properties', 'remove',
	'remove_callback',    #'savefig', keeping plt instead
	'sca', 'set', 'set_agg_filter', 'set_alpha', 'set_animated', 'set_canvas',
	'set_clip_box', 'set_clip_on', 'set_clip_path', 'set_constrained_layout',
	'set_constrained_layout_pads', 'set_dpi', 'set_edgecolor', 'set_facecolor',
	'set_figheight'
	,    # default 4.8 # 'set_figure', # deprecated as of matplotlib 3.10.0
	'set_figwidth', # default 6.4
	'set_frameon',       'set_gid',       'set_in_layout', 'set_label',
	'set_layout_engine', 'set_linewidth', 'set_mouseover', 'set_path_effects',
	'set_picker', 'set_rasterized',   'set_size_inches',   'set_sketch_params',
	'set_snap',   'set_tight_layout', 'set_transform', 'set_url', 'set_visible',
	'set_zorder', # 'show', # keeping plt instead
	'stale', 'stale_callback', 'sticky_edges', 'subfigs',
	'subfigures', #	 subplot_mosaic',
	'subplotpars', #	 subplots','subplots_adjust',
	'suppressComposite', # 'suptitle', # keeping plt instead
	'supxlabel', 'supylabel', #'text',
	'texts', #'tight_layout',
	'transFigure', 'transSubfigure', 'update',
	'update_from', #'waitforbuttonpress',
	'zorder'
);
my @plt_methods = (
	'AbstractContextManager', 'Annotation', 'Arrow', 'Artist', 'AutoLocator',
	'AxLine', 'Axes', 'BackendFilter',          'Button', 'Circle', 'Colorizer',
	'ColorizingArtist', 'Colormap',     'Enum', 'ExitStack', 'Figure',
	'FigureBase',   'FigureCanvasBase', 'FigureManagerBase', 'FixedFormatter',
	'FixedLocator', 'FormatStrFormatter', 'Formatter',       'FuncFormatter',
	'GridSpec',     'IndexLocator',       'Line2D', 'LinearLocator', 'Locator',
	'LogFormatter', 'LogFormatterExponent', 'LogFormatterMathtext',
	'LogLocator', 'MaxNLocator', 'MouseButton', 'MultipleLocator', 'Normalize',
	'NullFormatter',   'NullLocator', 'PolarAxes', 'Polygon',      'Rectangle',
	'ScalarFormatter', 'Slider',      'Subplot', 'SubplotSpec', 'TYPE_CHECKING',
	'Text', 'TickHelper',   'Widget',    'acorr',  'angle_spectrum', 'annotate',
	'annotations', 'arrow', 'autoscale', 'autumn', 'axes',           'axhline',
	'axhspan',     'axis',  'axline', 'axvline', 'axvspan', 'backend_registry',
	'bar_label', 'barbs', 'bone',    'box', 'boxplot',
	'broken_barh', 'cast',      'cbook', 'cla',  'clabel'
	,    #'clf', # I don't think you'd ever do that, also redundant with fig
	'clim',      'close',   'cm',      'cohere', 'color_sequences', 'colorbar',
	'colormaps', 'connect', 'contour', 'contourf', 'cool', 'copper', 'csd',
	'cycler',              'delaxes', 'disconnect', 'draw',      'draw_all',
	'draw_if_interactive', 'ecdf',    'errorbar',   'eventplot', 'figaspect',
	'figimage',     'figlegend', 'fignum_exists',   'figtext', 'figure', 'fill',
	'fill_between', 'fill_betweenx', 'findobj',     'flag', 'functools', 'gca',
	'gcf', 'gci', 'get', 'get_backend', 'get_cmap', 'get_current_fig_manager',
	'get_figlabels', 'get_fignums', 'get_plot_commands', 'get_scale_names',
	'getp',    'ginput', 'gray', 'grid', 
	'hot',     'hsv',    'importlib', 'imread', 'imsave', 'inferno',
	'inspect', 'install_repl_displayhook', 'interactive', 'ioff', 'ion',
	'isinteractive',  'jet', 'legend', 'locator_params', 'logging', 'loglog',
	'magma',          'magnitude_spectrum', 'margins', 'matplotlib', 'matshow',
	'minorticks_off', 'minorticks_on',      'mlab',    'new_figure_manager',
	'nipy_spectral',  'np',  'overload', 'pause',  'pcolor', 'pcolormesh',
	'phase_spectrum', 'pie', 'pink',     'plasma', 'plot', 'plot_date', 'polar',
	'prism', 'psd', 'quiver', 'quiverkey', 'rc', 'rcParams', 'rcParamsDefault',
	'rcParamsOrig', 'rc_context', 'rcdefaults', 'rcsetup', 'rgrids', 'savefig',
	'sca', #'scatter', # taken by "ax"
	'sci', 'semilogx', 'semilogy', 'set_cmap',  'set_loglevel', 'setp', 'show',
	'specgram',   'spring', 'spy', 'stackplot', 'stairs',       'stem', 'step',
	'streamplot', 'style',
	'subplot',    # nrows, ncols : int, default: 1
	'subplot2grid',    'subplot_mosaic', 'subplot_tool', 'subplots',
	'subplots_adjust', 'summer', 'suptitle', 'switch_backend', 'sys', 'table',
#	'text'
	, # text(x: 'float', y: 'float', s: 'str', fontdict: 'dict[str, Any] | None' = None, **kwargs) -> 'Text'
	'thetagrids',   'threading',# 'tick_params',
	'tight_layout', 'time', 'title', 'tricontour', 'tricontourf', 'tripcolor',
	'triplot',
#'twinx', 'twiny',
	'uninstall_repl_displayhook', 'violinplot',
	'viridis', 'waitforbuttonpress', 'winter', 'xcorr', 'xkcd',# 'vlines'
	'xlabel','xscale','ylabel', 'ylim', 'yscale',
#	'xlim','xticks','yticks'
);

my @arg = ('add', 'cmap', 'data', 'execute', 'fh', 'ncol', 'ncols', 'nrow', 'nrows', 'p', 'plot_type',  'plots', 'plot', 'output_file', 'scale', 'scalex', 'scaley', 'show', 'twinx');
# Options of plt itself, which no helper takes. "shared_colorbar" was in @arg,
# so every plot type accepted it inside a subplot and did nothing with it;
# plt hands it only to the subplot that draws the shared colorbar, whose type
# lists it among its own options.
my @plt_arg = ('shared_colorbar');
# Every keyword this module spelled with a dot up to 0.318, and what it is
# called now. The old spellings are refused, not accepted: see
# refuse_dotted_keywords.
my %undotted_keyword = (
	'col.labels'      => 'col_labels',
	'colorbar.on'     => 'colorbar_on',
	'key.order'       => 'key_order',
	'output.file'     => 'output_file',
	'plot.type'       => 'plot_type',
	'row.labels'      => 'row_labels',
	'set.options'     => 'set_options',
	'shared.colorbar' => 'shared_colorbar',
	'show.colorbar'   => 'show_colorbar',
	'show.legend'     => 'show_legend',
	'show.numbers'    => 'show_numbers',
	'twinx.args'      => 'twinx_args',
	'undef.color'     => 'undef_color',
	'xscale.hexbin'   => 'xscale_hexbin',
	'yscale.hexbin'   => 'yscale_hexbin',
);
my @cb_arg = (
'cbdrawedges', # for colarbar: Whether to draw lines at color boundaries
'cblabel',		# The label on the colorbar's long axis
'cblocation', # of the colorbar None or {'left', 'right', 'top', 'bottom'}
'cb_min',
'cb_max',
'cborientation', # None or {'vertical', 'horizontal'}
'cbpad',         # pad : float, default: 0.05 if vertical, 0.15 if horizontal; Fraction of original Axes between colorbar and new image Axes
'cb_logscale');
my %opt = (
	barplot_helper => [
	'color'
	, # :mpltype:`color` or list of :mpltype:`color`, optional; The colors of the bar faces. This is an alias for *facecolor*. If both are given, *facecolor* takes precedence # if entering multiple colors, quoting isn't needed
	'edgecolor'	, # optional; The colors of the bar edges.
	'key_order',    # define the keys in an order (an array reference)
	'label',        # an array of labels for grouped bar plots
	'linewidth', # float or array, optional; Width of the bar edge(s). If 0, don't draw edges
	'log'	,   # bool, default: False; If *True*, set the y-axis to be log scale.
	'logscale', # equivalent to "log"
	'stacked',    # stack the groups on top of one another; default 0 = off
	'width',      # float or array, default: 0.8; The width(s) of the bars.
	'xerr', # float or array-like of shape(N,) or shape(2, N), optional. If not *None*, add horizontal / vertical errorbars to the bar tips. The values are +/- sizes relative to the data:        - scalar: symmetric +/- values for all bars #        - shape(N,): symmetric +/- values for each bar #        - shape(2, N): Separate - and + values for each bar. First row #          contains the lower errors, the second row contains the upper #          errors. #        - *None*: No errorbar. (Default)
	'yerr',    # same as xerr, but better with bar
	],
	boxplot_helper => [
	 'color', # one color for every box; "colors" is the hash of one per key
	 'colors', 'key_order',
	 'logscale', # array of "x" and/or "y"
	 'notch', # Whether to draw a notched boxplot (`True`), or a rectangular boxplot (`False`)
	 'orientation',# {'vertical', 'horizontal'}, default: 'vertical'
	 'showcaps',   # bool: Show the caps on the ends of whiskers; default "True"
	 'showfliers', #bool, default: :rc:`boxplot.showfliers`; Show the outliers beyond the caps.
	 'showmeans'   #bool, default: :rc:`boxplot.showmeans`
	],
	colored_table_helper => [@cb_arg,
		'col_labels',
		'cmap',		# the cmap used for coloring
		'colorbar_on', # only draw if colorbar is on
		'default_undefined',	# what value should undefined values be assigned to?
		'mirror',   # $data{A}{B} = $data{B}{A}
		'row_labels',	# row labels
		'shared_colorbar', # array of 0-based indices for sharing a colorbar
		'show_numbers',# show the numbers or not, by default off.  0 = "off"; "show_numbers" > 0 => "on"
		'undef_color', # what color will undefined points be
	],
	hexbin_helper => [ @cb_arg,
	  'cb_logscale',
	  'cmap',         # "gist_rainbow" by default
	  'colorbar_on',  # only draw colorbar if colorbar is on
	  'key_order',    # define the keys in an order (an array reference)
	  'marginals',  # If marginals is *True*, plot the marginal density as colormapped rectangles along the bottom of the x-axis and left of the y-axis.
	  'mincnt'
	  , # int >= 0, default: 0 If > 0, only display cells with at least *mincnt*        number of points in the cell.
		'shared_colorbar', # array of 0-based indices for sharing a colorbar
	  'vmax'
	  , #  When using scalar data and no explicit *norm*, *vmin* and *vmax* define the data range that the colormap cover
	  'vmin'
	  , # When using scalar data and no explicit *norm*, *vmin* and *vmax* define the data range that the colormap cover
	  'xbins',    # default 15
	  'xscale_hexbin', # 'linear', 'log'}, default: 'linear': Use a linear or log10 scale on the horizontal axis.
	  'ybins',    # default 15
	  'yscale_hexbin', # 'linear', 'log'}, default: 'linear': Use a linear or log10 scale on the vertical axis.
	],
	hist_helper => [
	  'alpha',    # default 0.5; same for all sets
	  'key_order', # the order the sets are drawn in, and so of the legend; default sorted
	  'bins'
	  , # int or sequence or str, default: :rc:`hist.bins`If *bins* is an integer, it defines the number of equal-width bins in the range. If *bins* is a sequence, it defines the bin edges, including the left edge of the first bin and the right edge of the last bin; in this case, bins may be unequally spaced.  All but the last  (righthand-most) bin is half-open
	  'color', # a hash, where keys are the keys in data, and values are colors, e.g. X => 'blue'
	  'logscale',       # array of "x" and/or "y"; a scalar is refused
	  'orientation',    # {'vertical', 'horizontal'}, default: 'vertical'
	  'show_legend'
	],
	hist2d_helper => [@cb_arg,
	  'cb_logscale',
	  'cmap',         # "gist_rainbow" by default
	  'cmax',         # All bins that has count < *cmin* or > *cmax* will not be displayed
	  'cmin',         # color min
	  'colorbar_on',  # only draw colorbar if colorbar is on
	  'density',      # density : bool, default: False
	  'key_order',    # define the keys in an order (an array reference)
	  'logscale',     # logscale, an array of axes that will get log scale
	  'shared_colorbar', # array of 0-based indices for sharing a colorbar
	  'show_colorbar',
	  'vmax'
	  , #  When using scalar data and no explicit *norm*, *vmin* and *vmax* define the data range that the colormap cover
	  'vmin'
	  , # When using scalar data and no explicit *norm*, *vmin* and *vmax* define the data range that the colormap cover
	  'xbins',    # default 15
	  'xmin', 'xmax', 'ymin', 'ymax',
	  'ybins',    # default 15
	],
	imshow_helper => [@cb_arg,
	  'cblabel', # colorbar label
	  'cbdrawedges', # for colorbar
	  'cblocation', # of the colorbar None or {'left', 'right', 'top', 'bottom'}
	  'cborientation', # None or {'vertical', 'horizontal'}
	  'cmap', # The Colormap instance or registered colormap name used to map scalar data to colors
	  'colorbar_on', # only draw if colorbar is on
	  'shared_colorbar', # array of 0-based indices for sharing a colorbar
	  'stringmap', # 'H' => 'Alpha helix'
	  'vmax', # float
	  'vmin', # flat
	],
	pie_helper => [
	 'autopct',    # percent wise
	 'key_order',
	 #labeldistance and pctdistance are ratios of the radius; therefore they vary between 0 for the center of the pie and 1 for the edge of the pie, and can be set to greater than 1 to place text outside the pie https://matplotlib.org/stable/gallery/pie_and_polar_charts/pie_features.html
	 'labeldistance',
	 'pctdistance',
   ],
	plot_helper => [
	 'key_order',   # an array of key strings (which are defined in data)
	 'logscale',    # an array of "x" and/or "y"
	 'show_legend', # be default on; should be 0 if off
	 'set_options',
	 'twinx_args'
	],
	venn_proportional_area_helper => [
	 'alpha',       # float, opacity of the set circles (matplotlib_venn default 0.4)
	 'key_order',   # array ref: the order (and hence the set labels) of the sets
	 'set_colors',  # array ref of colors, one per set, e.g. ['red','green']
	],
	scatter_helper => [@cb_arg,
	 'color_key',    # which of data keys is the color key
	 'cmap',         # for 3-set scatterplots; default "gist_rainbow"
	 'colorbar_on',  # only draw colorbar if colorbar is on
	 'keys', # specify the order, otherwise alphabetical #'log', # if set to > 1, the y-axis will be logarithmic # 's', # float or array-like, shape (n, ), optional. The marker size in points**2 (typographic points are 1/72 in.).
	  'logscale', # "x" and/or "y" as an aray
	 'key_order',    # the order of the sets of a hash of sets; default sorted
	 'shared_colorbar', # array of 0-based indices for sharing a colorbar
	 'show_legend',  # label each of several sets for the legend; default on, 0 or 'False' for off
	 'set_options'    # color = 'red', marker = 'v', etc.
	],
	violin_helper => [
	 'color',      # one color for every violin; "colors" is the hash of one per key
	 'colors',
	 'edgecolor',
	 'key_order',
	 'medians',
	 'logscale',   # array: "x" and/or "y"
	 'orientation',# {'vertical', 'horizontal'}, default: 'vertical'
	 'whiskers'
	],
	wide_helper => [
	  'color',		   # a hash, with each key assigned to a color "blue" or something
	  'show_legend',  # be default on; should be 0 if off
	],
);
# plot_type => the %opt key holding that type's own keywords. "plt" dispatches
# on the same pairing (%dispatch, inside plt), but the option lists are needed
# out here too, so that a keyword rejected before dispatch can still be
# reported against the list for the type the caller actually asked for.
my %opt_key_of_type = (
	bar                    => 'barplot_helper',
	barh                   => 'barplot_helper',
	boxplot                => 'boxplot_helper',
	colored_table          => 'colored_table_helper',
	hexbin                 => 'hexbin_helper',
	hist                   => 'hist_helper',
	hist2d                 => 'hist2d_helper',
	imshow                 => 'imshow_helper',
	pie                    => 'pie_helper',
	plot                   => 'plot_helper',
	scatter                => 'scatter_helper',
	venn_proportional_area => 'venn_proportional_area_helper',
	violin                 => 'violin_helper',
	violinplot             => 'violin_helper',
	wide                   => 'wide_helper',
);
my @all_opt;
my %types_of_opt;    # keyword => array of the plot types whose own list has it
foreach my $type ( sort keys %opt_key_of_type ) {
	foreach my $keyword ( @{ $opt{ $opt_key_of_type{$type} } } ) {
		push @all_opt, $keyword;
		next if grep { $_ eq $type } @{ $types_of_opt{$keyword} // [] };
		push @{ $types_of_opt{$keyword} }, $type;
	}
}
sub edit_distance {
	# Optimal string alignment distance between two strings.
	#
	# Levenshtein with one extra case: two adjacent characters swapped count
	# as one edit, not two, because "widht" for "width" and "hsit" for "hist"
	# are the commonest way to mistype a keyword and a plain Levenshtein
	# threshold tight enough to be useful misses them.
	#
	# Three rows of the matrix are kept, since the transposition case reaches
	# two rows back; that is the only difference from the usual two-row form.
	my ( $x, $y ) = @_;
	my @prev2;
	my @prev = ( 0 .. length $y );
	foreach my $i ( 1 .. length $x ) {
		my @cur = ($i);
		foreach my $j ( 1 .. length $y ) {
			my $xc   = substr( $x, $i - 1, 1 );
			my $yc   = substr( $y, $j - 1, 1 );
			my $cost = ( $xc eq $yc ) ? 0 : 1;
			$cur[$j] = min(
				$cur[ $j - 1 ] + 1,        # insertion
				$prev[$j] + 1,             # deletion
				$prev[ $j - 1 ] + $cost    # substitution, or a match
			);
			if (   ( $i > 1 )
				&& ( $j > 1 )
				&& ( $xc eq substr( $y, $j - 2, 1 ) )
				&& ( $yc eq substr( $x, $i - 2, 1 ) ) ) {
				$cur[$j] = min( $cur[$j], $prev2[ $j - 2 ] + 1 );    # transposition
			}
		}
		@prev2 = @prev;
		@prev  = @cur;
	}
	return $prev[ length $y ];
}
sub resembles {
	# Whether $keyword is a plausible reading of the mistyped $bad.
	#
	# $bad and $keyword arrive already normalised (case folded, "." and "_"
	# dropped) so that the separator slips this module invites -- "key.order"
	# for "key_order", "show.legend" for "show_legend" -- cost nothing.
	#
	# Two ways in, for two kinds of mistake. Containment catches a keyword
	# reached for by the wrong name: "xlim" for "set_xlim", "legend" for
	# "show_legend". It is capped at 6 characters of difference, because
	# without a cap "log" pulls in "LogFormatterExponent" and every other
	# method with "log" buried in it. Edit distance catches the typing slips,
	# at one edit per three characters and never fewer than one: a
	# 4-character keyword such as "xlim" admits a single edit ("ylim"), and
	# only from 6 characters is a second allowed. A flat threshold of 2
	# instead matches most of the 4-character method names against each other.
	my ( $bad, $keyword ) = @_;
	my $difference = abs( length($keyword) - length($bad) );
	if ( $difference <= 6 ) {
		return 1 if index( $keyword, $bad ) >= 0;
		return 1 if index( $bad, $keyword ) >= 0;
	}
	my $max_edits = int( length($bad) / 3 ) || 1;
	return ( edit_distance( $bad, $keyword ) <= $max_edits );
}
sub normalise_keyword {
	# Case folded with "." and "_" dropped, so that keywords are compared on
	# their letters alone. This module spells the same idea both ways in
	# different places ("cb_min" beside "cblabel"), so a caller has no way to
	# be sure which separator a keyword uses.
	my ($keyword) = @_;
	$keyword = lc $keyword;
	$keyword =~ s/[._]//g;
	return $keyword;
}
sub similar_keywords {
	# The accepted keywords that a mistyped one plausibly meant, closest
	# first. $preferred, if given, is the plot type's own keyword list: those
	# are ranked ahead of equally-close matplotlib method names, since a
	# caller writing "log" at a "hist" wants "logscale", not "loglog".
	my ( $bad, $accepted, $preferred ) = @_;
	my $norm = normalise_keyword($bad);
	return () if $norm eq '';
	my %is_preferred = map { $_ => 1 } @{ $preferred // [] };
	my ( %seen, @scored );
	foreach my $keyword ( @{$accepted} ) {
		next if $seen{$keyword}++;    # the accepted lists are concatenated, so they repeat
		next unless resembles( $norm, normalise_keyword($keyword) );
		push @scored, [ $is_preferred{$keyword} ? 0 : 1, edit_distance( $norm, normalise_keyword($keyword) ), $keyword ];
	}
	@scored = sort {
		    $a->[0] <=> $b->[0]
		 || $a->[1] <=> $b->[1]
		 || $a->[2] cmp $b->[2]
	} @scored;
	# 5, measured: take every option of every plot type in turn and ask what
	# the types that do not accept it would suggest for it (1688 cases). 82
	# of them produce more than 5 suggestions -- up to 14 -- and in every one
	# of the 82, everything past the 5th is a matplotlib method name that
	# merely shares a stem ("pcolor", "Colormap", "tripcolor" for "color"),
	# never an option of any plot type. Re-measure before raising this.
	splice @scored, 5 if scalar @scored > 5;
	return map { $_->[2] } @scored;
}
sub keywords_of_other_types {
	# The keywords that resemble the mistyped one, are not accepted here, but
	# are accepted by some other plot type. The caller looks each one up in
	# %types_of_opt to say which types those are.
	#
	# This is the mistake the module's shape invites most. "stacked" is real,
	# and so are "notch" and "bins" -- just not for the plot type in hand --
	# so a bare "isn't defined" reads like the module is wrong. Naming the
	# types that do take the keyword answers the question the caller is
	# actually asking.
	my ( $bad, $accepted ) = @_;
	my $norm = normalise_keyword($bad);
	return () if $norm eq '';
	my %is_accepted = map { $_ => 1 } @{$accepted};
	my @scored;
	foreach my $keyword ( sort keys %types_of_opt ) {
		next if $is_accepted{$keyword};
		next unless resembles( $norm, normalise_keyword($keyword) );
		push @scored, [ edit_distance( $norm, normalise_keyword($keyword) ), $keyword ];
	}
	@scored = sort { $a->[0] <=> $b->[0] || $a->[1] cmp $b->[1] } @scored;
	# Fewer than the cap above, because each of these costs a whole line of
	# the message, and they are drawn from the 85 keywords the plot types
	# define between them rather than the 450-odd names a plot also accepts,
	# so the ranking has much less to choose between.
	splice @scored, 4 if scalar @scored > 4;
	return map { $_->[1] } @scored;
}
sub bad_keyword_error {
	# Die naming each unrecognised keyword, with the accepted keywords it
	# resembles.
	#
	# The accepted set is not one list: "notch" is a boxplot keyword and
	# "stacked" a bar keyword, and each helper validates against its own. The
	# caller passes the list it just checked against, so the suggestions are
	# the ones that would have worked where the caller was.
	#
	# args: bad       => array ref of the unrecognised keywords
	#       accepted  => array ref of the keywords that would have been taken
	#       preferred => array ref, optional: the subset to rank first
	#       type      => the plot_type being drawn, when one is known
	#       sub       => the subroutine doing the checking, named when the
	#                    type is not known (several subplots, no one type)
	my ($args) = @_;
	my $where =
	 defined $args->{type}
	 ? "for plot_type \"$args->{type}\""
	 : "in $args->{sub}";
	my ( @lines, $any_help );
	foreach my $bad ( sort @{ $args->{bad} } ) {
		my @similar = similar_keywords( $bad, $args->{accepted}, $args->{preferred} );
		if ( scalar @similar > 0 ) {
			$any_help = 1;
			push @lines, "\"$bad\" isn't defined $where, perhaps you meant one of these defined keywords: ("
			 . join( ', ', @similar ) . ')';
		} else {
			push @lines, "\"$bad\" isn't defined $where";
		}
		foreach my $keyword ( keywords_of_other_types( $bad, $args->{accepted} ) ) {
			$any_help = 1;
			push @lines, "\t\"$keyword\" is a defined keyword, but for plot_type "
			 . join( ', ', @{ $types_of_opt{$keyword} } );
		}
	}
	# Nothing resembled anything, here or elsewhere, so the caller has been
	# given no way forward: fall back to printing the whole accepted list, as
	# this module did before it could suggest anything.
	unless ($any_help) {
		my %seen;
		my @sorted = sort grep { !$seen{$_}++ } @{ $args->{accepted} };
		p @sorted, array_max => scalar @sorted;
		say STDERR "the keywords above are the ones defined $where.";
	}
	die join( "\n", @lines );
}
sub check_plot_type {
	# Die unless "plot_type" names a type this module draws, saying which of
	# the types it resembles was probably meant.
	#
	# "plot_type" is the one argument to plt whose *value* is drawn from a
	# fixed list, so a typo in it deserves the same answer a typo in a keyword
	# gets: the suggestions come from the matcher above, run over the type
	# names instead of over a type's options. Before this, a mistyped type
	# printed the whole args hash and died "barr isn't defined" at a single
	# plot, and reached %dispatch as an undef code ref -- "Can't use an
	# undefined value as a subroutine reference" -- at a subplot.
	#
	# It is also checked before the keywords are, because an unrecognised type
	# leaves plt with no type-specific option list to check them against: the
	# check falls back to the union of every type's options, and the caller is
	# told which of their options do not exist rather than that their type
	# does not.
	#
	# args: type  => the plot_type given, which must be defined
	#       where => optional phrase saying which plot it was given for, e.g.
	#                'at subplot 2'; omitted for a single plot, which has only
	#                the one.
	my ($args) = @_;
	my $type = $args->{type};
	return if defined $opt_key_of_type{$type};
	my $where = defined $args->{where} ? " $args->{where}" : '';
	my $norm  = normalise_keyword($type);
	my @scored;
	foreach my $known ( sort keys %opt_key_of_type ) {
		next unless resembles( $norm, normalise_keyword($known) );
		push @scored, [ edit_distance( $norm, normalise_keyword($known) ), $known ];
	}
	@scored = sort { $a->[0] <=> $b->[0] || $a->[1] cmp $b->[1] } @scored;
	# No cap, unlike the keyword suggestions: there are 15 plot types in all,
	# so the whole list is shorter than the 5 suggestions a keyword is allowed
	# and printing all of it costs the reader nothing.
	if ( scalar @scored > 0 ) {
		die "\"$type\" isn't a defined plot_type$where, perhaps you meant one of these defined plot types: ("
		 . join( ', ', map { $_->[1] } @scored ) . ')';
	}
	die "\"$type\" isn't a defined plot_type$where; the defined plot types are: ("
	 . join( ', ', sort keys %opt_key_of_type ) . ')';
}
sub decoded_text {
	# A string as characters, for writing through the script's UTF-8 layer.
	#
	# Raw UTF-8 bytes -- a key read from a file with no decoding layer, or
	# written in a script without "use utf8" -- are decoded, or each byte of a
	# "\x{3c1}" would be written as a character of its own. A string that is
	# already characters is left alone, and so is one whose bytes are not
	# UTF-8: a native "\xb0C" is the two characters it says, and decoding it
	# regardless, as quote_text did, turned the degree sign into U+FFFD.
	my ($str) = @_;
	return $str if ( not defined $str ) || Encode::is_utf8($str) || ( $str !~ m/[\x80-\xff]/ );
	my $copy    = $str;    # decode() with FB_CROAK consumes its argument
	my $decoded = eval { Encode::decode( 'UTF-8', $copy, Encode::FB_CROAK ) };
	return defined $decoded ? $decoded : $str;
}
sub decoded_data {
	# decoded_text of every string in a structure bound for write_data, in a
	# copy. A number is passed through untouched: a regex match would mark it
	# as a string, and the JSON encoder would then write it as one.
	my ($data) = @_;
	my $ref = ref $data;
	return [ map { decoded_data($_) } @{$data} ] if $ref eq 'ARRAY';
	return { map { decoded_text($_) => decoded_data( $data->{$_} ) } keys %{$data} } if $ref eq 'HASH';
	return $data if $ref || ( not defined $data ) || looks_like_number($data);
	return decoded_text($data);
}
sub py_str {
	# Render a Perl string as a Python single-quoted string literal.
	#
	# Legend labels, colorbar labels and the like are user data (data keys,
	# group names), so a name such as "Farmer's" would otherwise close the
	# literal early and emit unparseable Python. Backslashes are doubled
	# first, which also makes a mathtext label like '$\alpha$' survive as
	# written instead of being read as a Python escape.
	my ($str) = @_;
	$str = decoded_text( $str // '' );    # data keys reach here as raw bytes as often as labels do
	$str =~ s/\\/\\\\/g;	# backslash first, or the escapes below get doubled
	$str =~ s/'/\\'/g;
	$str =~ s/\n/\\n/g;
	$str =~ s/\r/\\r/g;
	$str =~ s/\t/\\t/g;
	# Every other control character as a hex escape. A NUL went through as it
	# stood, and Python refuses the whole script for it: "source code string
	# cannot contain null bytes".
	$str =~ s/([\x00-\x08\x0b\x0c\x0e-\x1f\x7f])/sprintf( '\\x%02x', ord $1 )/ge;
	return "'$str'";
}
sub py_list {
	# The contents of a Python sequence literal: every item rendered by py_str
	# and joined with commas, so the caller wraps it in the [] or () it needs.
	#
	# The sites that take this are the ones that write user data -- data keys,
	# tick labels, set members -- into a list. Written by hand as
	# '["' . join('","', @keys) . '"]' they broke on a key holding a double
	# quote (a SyntaxError) and, worse, silently on one holding a backslash:
	# a "$\alpha$" key reached matplotlib as "$<BEL>lpha$", because Python read
	# the "\a" of a double-quoted literal as an escape.
	return join( ',', map { py_str($_) } @_ );
}
sub py_num {
	# A value that passed looks_like_number, as a Python numeric literal.
	#
	# looks_like_number accepts "nan", "inf", "Infinity" and a Perl NaN, and
	# each was written into the script as Perl stringifies it: "y = [1,NaN,3]"
	# died as "NameError: name 'NaN' is not defined". It also accepts
	# "0 but true", which is not Python either. A
	# finite value written in Python's own float syntax goes through as given,
	# so that no digits are lost to Perl's 15-digit stringification.
	#
	# Except for the leading zeros of a whole number, which are dropped: Python 3
	# refuses "007" as "leading zeros in decimal integer literals are not
	# permitted", and a column read from a file can hold such values. A float
	# such as "00.5" or "007e3" is legal Python and is left alone.
	my ($n) = @_;
	my $nonfinite = nonfinite_name($n);
	return "float('$nonfinite')" if defined $nonfinite;
	if ( $n =~ m/^\s*([-+]?)0*(\d+)\s*$/ ) {
		return "$1$2";
	}
	return $n if $n =~ m/^\s*[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?\s*$/;
	return 0 + $n;
}
sub py_nums {
	# py_num of each value, joined with commas, for the caller to bracket.
	return join( ',', map { py_num($_) } @_ );
}
sub is_finite {
	# Whether a value that passed looks_like_number is neither NaN nor infinite.
	my $v = 0 + $_[0];
	return ( ( $v == $v ) && ( $v != 9**9**9 ) && ( $v != -9**9**9 ) ) ? 1 : 0;
}
sub is_nan {
	# Whether a value is a number that is NaN: a missing value, for the helpers
	# that drop missing values rather than draw them.
	return 0 unless looks_like_number( $_[0] );
	my $v = 0 + $_[0];
	return ( $v != $v ) ? 1 : 0;
}
sub nonfinite_name {
	# "nan", "inf" or "-inf" for a non-finite number, as numpy's float() reads
	# them; undef for a finite one.
	return undef if is_finite( $_[0] );
	my $v = 0 + $_[0];
	return ( $v != $v ) ? 'nan' : ( $v > 0 ) ? 'inf' : '-inf';
}
sub check_numbers {
	# Die unless every value of an option is a defined number, naming the option.
	my ( $values, $what, $current_sub ) = @_;
	my @bad = grep { ( not defined ) || ( not looks_like_number($_) ) } @{$values};
	return if scalar @bad == 0;
	die "$what must be numeric for $current_sub, but was given \"" . join( '", "', map { $_ // 'undef' } @bad ) . '"';
}
sub finite_values {
	# The values of a list that are numbers and finite, for a range computed in
	# Perl: min() and max() over a NaN answer by the order of the list, and an
	# infinite end leaves a range that nothing can be drawn in.
	return grep { ( defined ) && looks_like_number($_) && is_finite($_) } @_;
}
sub bool_option {
	# A yes-or-no option as 1 or 0, read as Python reads a bool.
	#
	# The documentation gives these options as Python bools -- "log => 'True'"
	# -- and the code tested them for Perl truth, so "log => 'False'" turned
	# the log scale on, the string being true in Perl. "True" and "False" in
	# any case, and any number, are taken; anything else is refused, naming the
	# option, since a word such as "yes" could mean either.
	my ( $value, $option, $current_sub ) = @_;
	return 0 unless defined $value;
	if ( ref $value ) {
		die "\"$option\" is True or False (or 1 or 0) for $current_sub, not a " . ( ref $value ) . ' reference';
	}
	return 1 if $value =~ m/^\s*true\s*$/i;
	return 0 if $value =~ m/^\s*(?:false|none)?\s*$/i;    # "" and None are false in Python too
	return ( ( 0 + $value ) != 0 ) ? 1 : 0 if looks_like_number($value);
	die "\"$option\" is True or False (or 1 or 0) for $current_sub, not \"$value\"";
}
sub cb_limits {
	# "cb_min" and "cb_max" as the "vmin" and "vmax" a helper writes.
	#
	# colored_table takes the ends of its color scale as cb_min and cb_max,
	# and every other helper with a colorbar accepts them too, since they are
	# in @cb_arg -- but read vmin and vmax, where it read anything, and left
	# cb_min and cb_max unread. Each is now the other's synonym. Giving both
	# for the same end is refused, rather than one of them silently winning.
	# Each caller checks the result is a number, as it checked vmin and vmax.
	my ( $plot, $current_sub ) = @_;
	foreach my $pair ( [ 'cb_min', 'vmin' ], [ 'cb_max', 'vmax' ] ) {
		my ( $cb, $v ) = @{$pair};
		next unless defined $plot->{$cb};
		if ( defined $plot->{$v} ) {
			die "\"$cb\" and \"$v\" both set the same end of the color scale in $current_sub; give one of them";
		}
		$plot->{$v} = delete $plot->{$cb};
	}
}
sub norm_args {
	# The keyword arguments of a drawing call that set its color scale,
	# each led by ", ": "vmin" and "vmax", or with "log" a LogNorm holding
	# them, since matplotlib refuses vmin and vmax beside a norm.
	#
	# args: lo, hi   => the ends of the scale, either undef to take it from
	#                   "values", or from matplotlib if there are none
	#       values   => array ref, optional: the values being colored
	#       log      => Perl true for a log scale
	#       fh, sub  => the script, and the helper, for the import and errors
	# A log scale cannot start at 0 or below, so its default bottom is the
	# smallest value above 0, as LogNorm would choose for itself.
	my ($args) = @_;
	my ( $lo, $hi ) = @{$args}{qw(lo hi)};
	my @values = finite_values( @{ $args->{values} // [] } );
	if ( $args->{log} ) {
		$lo = $lo // min( grep { $_ > 0 } @values );
		if ( not defined $lo ) {
			die "\"cb_logscale\" needs a color value above 0 to start the scale at, or a \"vmin\" or \"cb_min\" above 0, and $args->{sub} has neither";
		}
		if ( $lo <= 0 ) {
			die "\"cb_logscale\" cannot start at $lo in $args->{sub}: a log scale needs a minimum above 0";
		}
	} else {
		$lo = $lo // min(@values);
	}
	$hi = $hi // max(@values);
	my @kw;
	push @kw, 'vmin = ' . py_num($lo) if defined $lo;
	push @kw, 'vmax = ' . py_num($hi) if defined $hi;
	if ( $args->{log} ) {
		say { $args->{fh} } 'from matplotlib.colors import LogNorm';
		return ', norm = LogNorm(' . join( ', ', @kw ) . ')';
	}
	return join( '', map { ", $_" } @kw );
}
sub check_key_order {
	# The keys an ordering option names, as a list, dying unless it is an array
	# of distinct keys of "data".
	#
	# Without this the missing key reaches the writer as an undef and dies as
	# "Use of uninitialized value in join or string", which names neither the
	# key that is missing nor the option that asked for it. A key named twice
	# was drawn twice, and in a venn_proportional_area, whose sets are counted
	# from "data", it put one set in place of another: "key_order => ['A','A']"
	# drew A against itself and left B out. A string died as "Can't use string
	# as an ARRAY ref", and an empty array left nothing to draw.
	#
	# args: keys   => the option's value, which should be an array ref
	#       data   => the data hash they must all be keys of
	#       option => the option they came from, e.g. "key_order"
	#       sub    => the helper doing the checking
	my ($args) = @_;
	my $keys = $args->{keys};
	if ( ref $keys ne 'ARRAY' ) {
		my $got = ref $keys ? ( ref $keys ) . ' reference' : '"' . ( $keys // 'undef' ) . '"';
		die "\"$args->{option}\" is an array of keys of \"data\" in $args->{sub}, not $got";
	}
	if ( scalar @{$keys} == 0 ) {
		die "\"$args->{option}\" is an empty array in $args->{sub}; give the keys of \"data\" in the order to draw them";
	}
	if ( grep { ( not defined ) || ( ref ) } @{$keys} ) {
		die "\"$args->{option}\" holds something that is not a key of \"data\" in $args->{sub}";
	}
	my %n_named;
	my @twice = grep { $n_named{$_}++ == 1 } @{$keys};
	if ( scalar @twice > 0 ) {
		die "\"$args->{option}\" names " . join( ', ', map { "\"$_\"" } @twice ) . " more than once in $args->{sub}";
	}
	my @missing = grep { not exists $args->{data}{$_} } @{$keys};
	if ( scalar @missing > 0 ) {
		p @missing;
		die "the above keys are named in \"$args->{option}\" but are not keys of \"data\" in $args->{sub}";
	}
	return @{$keys};
}
sub logscale_axes {
	# The axes a "logscale" option asks for, refusing anything that is not an
	# axis name.
	#
	# The check this replaces was m/^([^xy])$/, which only ever saw one
	# character: "xy" and "" both passed it and emitted ax.set_xyscale("log")
	# and ax.set_scale("log"), neither of which matplotlib has. A scalar
	# "logscale => 'y'" died inside the dereference, as
	# "Can't use string ("y") as an ARRAY ref".
	#
	# "bar"/"barh" are not callers: their "logscale" is the scalar synonym for
	# "log", documented as such.
	my ( $logscale, $current_sub ) = @_;
	return () unless defined $logscale;
	if ( ref $logscale ne 'ARRAY' ) {
		my $got = ref $logscale ? ( ref $logscale ) . ' reference' : "\"$logscale\"";
		die "\"logscale\" must be an array of axis names, e.g. [ 'y' ], but $current_sub was given $got";
	}
	my @bad = grep { ( not defined $_ ) || ( $_ !~ m/^[xy]$/ ) } @{$logscale};
	if ( scalar @bad > 0 ) {
		p $logscale;
		die 'only "x" and "y" are allowed in "logscale" for ' . $current_sub
		 . ', not "' . join( '", "', map { $_ // 'undef' } @bad ) . '"';
	}
	return @{$logscale};
}
sub write_data {
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
	# 1. Create the JSON Encoder; allow_nonref: allows scalars (strings/numbers) to be encoded
	my $json_encoder = JSON::MaybeXS->new->utf8->allow_nonref;
	# 2. Serialize Perl Data -> JSON String; Passing data directly. JSON::MaybeXS handles refs + scalars automatically.
	my $json_string = $json_encoder->encode( decoded_data( $args->{data} ) );
	# 3. Base64 Encode the JSON String, not the reference
	my $b64_data = encode_base64($json_string, ''); 
	# Assign the b64 string to a temp python variable
	say {$args->{fh}} "$args->{name}_b64 = '$b64_data'";
	# Decode b64 -> bytes -> utf8 string -> json load -> python object
	say {$args->{fh}} "$args->{name} = json.loads(base64.b64decode($args->{name}_b64).decode('utf-8'))";
}
# The twin axis of each axes that has one, by the axes' python name: "ax0" =>
# "twinx_ax0". plot_helper makes one twin per axes and draws every twinned line
# on it, and plot_args reads (and deletes) the entry when it writes that axes'
# legend, so that the legend holds the twin's lines as well. plt empties it
# before it writes a figure, so a call that died part way leaves nothing behind.
my %twin_axes;
# The methods whose argument is usually bare text, which quote_text quotes.
# "supxlabel" and "supylabel" are figure methods, which are otherwise written
# as given: until 0.32 they were not here, so "supxlabel => 'Time'" wrote
# fig.supxlabel(Time), a NameError, where "suptitle => 'Time'" was quoted.
my @text_methods = ( 'set_title', 'set_xlabel', 'set_ylabel', 'suptitle', 'supxlabel', 'supylabel', 'xlabel', 'ylabel', 'title' );
sub quote_text {
	# A title or axis label as python: quoted, unless it is already python.
	#
	# Text holding a quote or a comma may be python of the caller's own --
	# "'Counts, by book'", "'title', fontsize = 20", 'r"$\it{anno}$"' or
	# 'label = "x", loc = "left"' -- and is left as written when it opens as
	# python does: with a string literal, which may carry a prefix such as r or
	# f, or with a keyword argument. Anything else is prose and is quoted. All
	# such text used to be left as written, so "Bob's data" became
	# set_xlabel(Bob's data), a SyntaxError, and "" became set_title(), a
	# TypeError for want of an argument.
	#
	# The literal has to close, and be all of the text or be followed by a
	# comma and the next argument. An opening quote was enough until 0.32, so
	# "'Tis the season" became set_title('Tis the season) and '"A" vs "B"'
	# became set_title("A" vs "B"), both SyntaxErrors.
	my ($text) = @_;
	$text = decoded_text($text);
	# py_str, not "'$text'": a backslash went through unescaped, so a
	# mathtext '$\alpha$' reached matplotlib with a bell character in it.
	return py_str($text) if $text =~ m/^([^\"\',]+)$/;
	return $text if $text =~ m/^\s*[rRbBuUfF]{0,2}(['"])(?:\\.|(?!\1)[^\\])*\1\s*(?:,|$)/s;
	return $text if $text =~ m/^\s*[A-Za-z_]\w*\s*=[^=]/;
	return py_str($text);
}
sub default_axis_labels {
	# "xlabel" and "ylabel" from the names of the two data keys of hexbin,
	# hist2d or scatter, for each axis the caller labelled in neither form.
	#
	# Only "xlabel" was looked at, so "set_xlabel => 'Custom'" got an "xlabel"
	# beside it, and plt's rename of "xlabel" to "set_xlabel" then wrote the
	# key's name over the caller's label. frame_to_data's $label_axis already
	# looked at both.
	my ( $plot, $x_key, $y_key ) = @_;
	foreach my $label ( [ 'xlabel', $x_key ], [ 'ylabel', $y_key ] ) {
		my ( $axis, $key ) = @{$label};
		next if ( defined $plot->{$axis} ) || ( defined $plot->{"set_$axis"} );
		$plot->{$axis} = py_str($key);
	}
}
sub plot_args {    # this is a helper function to other matplotlib subroutines
	my ($args) = @_;
	my $current_sub = ( split( /::/, ( caller(0) )[3] ) )[-1];
	if ( ref $args ne 'HASH' ) {
		die "args must be given as a hash ref, e.g. \"$current_sub({ data => \@blah })\"";
	}
	my @reqd_args = (
		'ax',   # ax1, ax2, etc. when there are multiple plots
		'fh',   # e.g. $py, $fh, which will be passed by the subroutine
		'args', # args to original function
	);
	my @undef_args = grep { !defined $args->{$_} } @reqd_args;
	if ( scalar @undef_args > 0 ) {
		p @undef_args;
		die 'the above args are necessary, but were not defined.';
	}
	# "emit_plt_fig" and "no_legend" are this sub's own arguments, not plot
	# options; see below.
	my @defined_args = ( @reqd_args, 'emit_plt_fig', 'no_legend', @ax_methods, @fig_methods, @plt_methods, @arg, @cb_arg );
	my @bad_args = grep {
	  my $key = $_;
	  not grep { $_ eq $key } @defined_args
	} keys %{$args};
	if ( scalar @bad_args > 0 ) {
		bad_keyword_error({
			bad      => \@bad_args,
			accepted => \@defined_args,
			sub      => $current_sub
		});
	}
	$args->{ax} = $args->{ax} // 'ax';
	# A copy, because the quoting below writes back into it: the hash can be
	# the caller's own ("twinx_args" hands one in untouched), and a second plot
	# drawn from it found its titles already wrapped in quotes.
	$args->{args} = { %{ $args->{args} } };
	# An array is one call per element, as for every other method below, so
	# each element is quoted. The array itself used to be, and
	# "set_title => ['First', 'Second']" wrote set_title('ARRAY(0x5b95...)').
	foreach my $item ( grep { defined $args->{args}{$_} } @text_methods ) {
		my $text = $args->{args}{$item};
		$args->{args}{$item} = ( ref $text eq 'ARRAY' ) ? [ map { quote_text($_) } @{$text} ] : ( ref $text ) ? $text : quote_text($text);
	}
	# Whether the "fig." and "plt." methods in this hash are written here as
	# well as the "ax." ones. 1 (the default) is what a subplot needs, since
	# nothing else writes them for it; plt() passes 0 for a single plot, whose
	# hash it walks itself afterwards. Both passes used to run over that one
	# hash, so every figure-wide and pyplot-wide option was written twice, and
	# the second pass ran print_type over text the first had already quoted:
	# suptitle => "'Counts, by book'" left plt.suptitle(''Counts, by book'')
	# in the script, a SyntaxError.
	$args->{emit_plt_fig} = $args->{emit_plt_fig} // 1;
	my @obj  = ( $args->{ax} );
	my @args = ( \@ax_methods );
	if ( $args->{emit_plt_fig} ) {
		push @obj,  'fig', 'plt';
		push @args, \@fig_methods, \@plt_methods;
	}
	foreach my $i ( 0 .. $#args ) {
		my @methods = grep { defined $args->{args}{$_} && ( $_ ne 'legend' ) } @{ $args[$i] };    # "legend" is written below, and only when something has a label
		# pyplot's functions act on the current axes, which after plt.subplots is
		# the last subplot and after a twinx() is the twin, so a subplot's own
		# "ylim" or "axhline" was drawn on some other subplot. This one is made
		# current first.
		if ( ( $obj[$i] eq 'plt' ) && ( grep { $_ ne 'show' } @methods ) ) {
			say {$args->{fh}} "plt.sca($args->{ax}) #line" . __LINE__;
		}
		# Only the pyplot calls are quoted, as plt() quotes a single plot's; the
		# axes and figure methods are written as given in both.
		my $arg_text = ( $obj[$i] eq 'plt' ) ? \&pyplot_arg : sub { $_[0] };
		foreach my $method (@methods) {
			my $ref = ref $args->{args}{$method};
			if ( ( $ref ne 'ARRAY' ) && ( $ref ne '' ) ) {
				die "$current_sub only accepts scalar or array types, but \"$ref\" was entered.";
			}
			if ( $ref eq '' ) {
				if ($method eq 'show') {
					next; # plt.show() is emitted by plt() after plt.savefig()
				} else {
					say {$args->{fh}} "$obj[$i].$method(" . $arg_text->( $args->{args}{$method} ) . ') #line' . __LINE__;
				}
				next;
			}
			# can only be ARRAY
			foreach my $j ( @{ $args->{args}{$method} } ) {
				say { $args->{fh} } "$obj[$i].$method(" . $arg_text->($j) . ') #line' . __LINE__;
			}
		}
	}
	return unless defined $args->{ax};
	my $legend   = $args->{args}{legend} // '';
	my $pie_plot = 0;
	if (   ( defined $args->{args}{plot_type} )
	  && ( $args->{args}{plot_type} eq 'pie' ) ) {
	  $pie_plot = 1;
	}
	return 1 if $pie_plot == 1;
	# pie charts don't get legends
	# A twin axis (see %twin_axes) is given no legend of its own: its lines go
	# in the legend of the axes it twins.
	return 1 if $args->{no_legend};
	say { $args->{fh} }
	"handles, labels = $args->{ax}.get_legend_handles_labels()";
	my $twin = delete $twin_axes{ $args->{ax} };
	if ( defined $twin ) {
		# One legend for both axes, drawn on the twin because the twin is drawn
		# over the axes it twins, and would cover a legend drawn on them. The
		# twin's lines were in no legend at all, or -- with "twinx_args" -- in a
		# second one drawn on top of the first, in the same "best" place.
		say { $args->{fh} } "twin_handles, twin_labels = $twin.get_legend_handles_labels()";
		say { $args->{fh} } 'handles += twin_handles';
		say { $args->{fh} } 'labels += twin_labels';
		say { $args->{fh} } 'if len(labels) > 0:';
		say { $args->{fh} } "\t$twin.legend(handles, labels" . ( length $legend ? ", $legend" : '' ) . ')';
		return 1;
	}
	say { $args->{fh} } 'if len(labels) > 0:';
	say { $args->{fh} } "\t$args->{ax}.legend($legend)";
}
sub barplot_helper { # this is a helper function to other matplotlib subroutines
	my ($args) = @_;
	my $current_sub = ( split( /::/, ( caller(0) )[3] ) )[-1]
	; # https://stackoverflow.com/questions/2559792/how-can-i-get-the-name-of-the-current-subroutine-in-perl
	if ( ref $args ne 'HASH' ) {
	  die
	"args must be given as a hash ref, e.g. \"$current_sub({ data => \@blah })\"";
	}
	my @reqd_args = (
	  'fh',      # e.g. $py, $fh, which will be passed by the subroutine
	  'plot',    # args to original function
	);
	my @undef_args = grep { !defined $args->{$_} } @reqd_args;
	if ( scalar @undef_args > 0 ) {
	  p @undef_args;
	  die 'the above args are necessary, but were not defined.';
	}
	my @opt = ('ax', @reqd_args, @ax_methods, @plt_methods, @fig_methods, @arg, @{ $opt{$current_sub} }	);
	my $plot      = $args->{plot};
	my @bad_opt = grep {
	  my $key = $_;
	  not grep { $_ eq $key } @opt
	} keys %{$plot};
	my $ax = $args->{ax} // '';
	if ( scalar @bad_opt > 0 ) {
		bad_keyword_error({
			bad       => \@bad_opt,
			accepted  => \@opt,
			preferred => $opt{$current_sub},
			type      => $plot->{plot_type},
			sub       => $current_sub
		});
	}
	my ( %ref_counts, $plot_type );
	foreach my $set ( keys %{ $plot->{data} } ) {
	  $ref_counts{ ref $plot->{data}{$set} }++;
	}
	if ( scalar keys %ref_counts > 1 ) {
		p $plot->{data};
		p %ref_counts;
		die
	"different kinds of data were entered to plot $ax which should be simple hash or hash of arrays.";
	}
	if ( defined $ref_counts{''} ) {
		$plot_type = 'simple';
	} elsif ( defined $ref_counts{'ARRAY'} ) {
		$plot_type = 'grouped';
	} elsif ( defined $ref_counts{'HASH'} ) {
		$plot_type = 'grouped';    # now make the hash of hash into a ARRAY structure
		my %key2;
		foreach my $key1 ( keys %{ $plot->{data} } ) {
			foreach my $key2 ( keys %{ $plot->{data}{$key1} } ) {
				$key2{$key2}++;
			}
		}
		# "|| $a cmp $b": two inner keys differing only in case ("a", "A") tied,
		# and hash order then chose which series came first, from run to run.
		my @key2 = sort { lc $a cmp lc $b || $a cmp $b } keys %key2;
		my %new_structure;
		foreach my $k1 ( keys %{ $plot->{data} } ) {
			@{ $new_structure{$k1} } = @{ $plot->{data}{$k1} }{@key2};
		}
		# The inner keys are the series, so a color given as a hash can be
		# answered here: turn it into the positional array the series loop
		# below reads. Given as a hash it was silently dropped, since that
		# loop only ever looked at an ARRAY.
		if ( ( defined $plot->{color} ) && ( ref $plot->{color} eq 'HASH' ) ) {
			my @uncolored = grep { not defined $plot->{color}{$_} } @key2;
			if ( scalar @uncolored > 0 ) {
				p @uncolored;
				die "the above series have no color defined in \"color\" in $current_sub";
			}
			$plot->{color} = [ @{ $plot->{color} }{@key2} ];
		}
		# A new array rather than "@{ $plot->{label} } = ...", which wrote the
		# series names into an array the caller may have passed as "label".
		$plot->{label} = [@key2];
		$plot->{data} = \%new_structure;
	} else {
	  p %ref_counts;
	  p $plot->{data};
	  die 'the above plot type is not yet programmed in to bar/barh';
	}
	# Read as a Python bool, as "log" is: it was compared with "==", so
	# "stacked => 'True'" died as 'Argument "True" isn't numeric', and a
	# negative number shifted the bars as though unstacked while keeping the
	# full width of stacked ones.
	$plot->{stacked} = bool_option( $plot->{stacked}, 'stacked', $current_sub );
	# "float only", as documented, and written bare: "width => 'wide'" was a
	# NameError in Python.
	if ( defined $plot->{width} ) {
		if ( ref $plot->{width} ) {
			die "\"width\" is one number for every bar in $current_sub, not a " . ref( $plot->{width} ) . ' reference';
		}
		check_numbers( [ $plot->{width} ], '"width"', $current_sub );
		die "\"width\" must be a finite number for $current_sub, not \"$plot->{width}\"" unless is_finite( $plot->{width} );
	}
	if (   ( $plot_type eq 'grouped' )
	  && ( defined $plot->{width} )
	  && ( $plot->{stacked} == 0 ) )
	{
	  say STDERR 'grouped, non-stacked barplots ignore width settings';
	  delete $plot->{width};
	}
	my @key_order;
	if ( defined $plot->{key_order} ) {
	  @key_order = check_key_order({
	  	keys   => $plot->{key_order},
	  	data   => $plot->{data},
	  	option => 'key_order',
	  	sub    => $current_sub
	  });
	} else {
	  @key_order = sort keys %{ $plot->{data} };
	}
	# A color per data key only means something for the simple form, where one
	# key is one bar, and for the hash-of-hashes form, whose inner keys named
	# the series and were turned into an array above. The hash-of-arrays form
	# has nothing to key a color hash by, and used to ignore it in silence.
	if ( ( $plot_type eq 'grouped' ) && ( ref $plot->{color} eq 'HASH' ) ) {
		die "$current_sub: \"color\" is a HASH, but this data is a hash of arrays, whose series have no names to key it by: give one color per series as an array, e.g. color => ['red','blue']";
	}
	# Every value reaches the script as it stands, so a non-numeric one
	# becomes a bare Python name: "data => { A => 'abc' }" wrote "vals = [abc]"
	# and died as a NameError when the script ran, pointing at the generated
	# file rather than at the data.
	foreach my $key (@key_order) {
		my @values = ( $plot_type eq 'simple' ) ? ( $plot->{data}{$key} ) : @{ $plot->{data}{$key} };
		my @bad = grep { defined && !looks_like_number($_) } @values;
		if ( scalar @bad > 0 ) {
			p @bad;
			die "the above values of \"$key\" are not numbers, which $current_sub needs";
		}
		next unless $plot_type eq 'simple';
		die "\"$key\" has an undefined value, which $current_sub cannot plot"
		 unless defined $plot->{data}{$key};
	}
	if ( $plot_type eq 'grouped' ) {
		# One bar per key per series, so a short array leaves a series with
		# more x positions than heights, which matplotlib rejects with a shape
		# mismatch naming neither the key nor the length it expected.
		my %n_values = map { $_ => scalar @{ $plot->{data}{$_} } } @key_order;
		my %lengths = map { $_ => 1 } values %n_values;
		if ( scalar keys %lengths > 1 ) {
			p %n_values;
			die "the above keys hold different numbers of values; every key of a grouped $plot->{plot_type} needs the same number";
		}
		# Nothing to draw, which died as "Can't use an undefined value as an
		# ARRAY reference" where the first series was looked for.
		if ( ( scalar keys %lengths == 1 ) && ( ( keys %lengths )[0] == 0 ) ) {
			die "every key of \"data\" holds an empty array, so $current_sub has no bars to draw";
		}
	}
	my $options = '';    # these args go to the plt.bar call
	if ( bool_option( $plot->{'log'}, 'log', $current_sub ) || $plot->{logscale} ) {    # "logscale" is documented as taking Perl truth, "log" as a Python bool
	  $options .= ', log = True';
	}    # args that can be either arrays or strings below; STRINGS:
	foreach my $c ( grep { defined $plot->{$_} } ( 'color', 'edgecolor' ) ) {
		next if ( ( $c eq 'color' ) && ( $plot_type eq 'grouped' ) && ( ref $plot->{$c} ne '' ) );
		my $ref = ref $plot->{$c};
		if ( $ref eq '' ) {    # single color
			$options .= ", $c = " . py_str( $plot->{$c} );
		} elsif ( $ref eq 'ARRAY' ) {
			$options .= ", $c = [" . py_list( @{ $plot->{$c} } ) . ']';
		} elsif ( $ref eq 'HASH' ) {
			# One color per bar, keyed as the bars are, as "color" is. An
			# "edgecolor" hash fell into an empty branch here and was dropped
			# without a word. Every bar of a grouped plot is one key of one
			# series, and the hash has nothing to say which.
			if ( ( $c eq 'edgecolor' ) && ( $plot_type eq 'grouped' ) ) {
				die "$current_sub: \"edgecolor\" is a HASH, which is keyed by bar and so only fits a simple hash of one bar per key: give a grouped plot one color, or an array of one per key";
			}
			next if $c eq 'color';    # written with the bars, below
			my @uncolored = grep { not defined $plot->{$c}{$_} } @key_order;
			if ( scalar @uncolored > 0 ) {
				p @uncolored;
				die "the above keys have no color defined in \"$c\" in $current_sub";
			}
			$options .= ", $c = [" . py_list( @{ $plot->{$c} }{@key_order} ) . ']';
		} else {
			die "ref \"$ref\" isn't defined";
		}
	} # args that can be either arrays or strings below; NUMERIC:
	# One width for every bar edge, or one per bar. Nothing checked it, so
	# "linewidth => 'thick'" was written as a bare Python name.
	foreach my $c ( grep { defined $plot->{$_} } ('linewidth') ) {
		my $ref = ref $plot->{$c};
		if ( ( $ref ne '' ) && ( $ref ne 'ARRAY' ) ) {
			p $args;
			die "$ref for $c isn't acceptable";
		}
		my @values = ( $ref eq 'ARRAY' ) ? @{ $plot->{$c} } : ( $plot->{$c} );
		check_numbers( \@values, "\"$c\"", $current_sub );
		$options .= ( $ref eq 'ARRAY' ) ? ", $c = [" . py_nums(@values) . ']' : ", $c = " . py_num( $plot->{$c} );
	}
	# Error bars take the shapes matplotlib does -- one number for every bar,
	# an array of one per bar, or an array of two such arrays, lower then upper
	# -- and a hash keyed by the data keys, each value one number or a
	# [ lower, upper ] pair. An array died as "ARRAY for yerr isn't acceptable"
	# though the options table offered it, and a hash value that was one number,
	# or a key left out of the hash, died dereferencing it.
	my $n_bars = scalar @key_order;
	foreach my $err ( grep { defined $plot->{$_} } ( 'xerr', 'yerr' ) ) {
		my $ref = ref $plot->{$err};
		if ( $ref eq '' ) {
			check_numbers( [ $plot->{$err} ], "\"$err\"", $current_sub );
			$options .= ", $err = " . py_num( $plot->{$err} );
		} elsif ( $ref eq 'ARRAY' ) {
			my @rows = ( grep { ref } @{ $plot->{$err} } ) ? @{ $plot->{$err} } : ( $plot->{$err} );
			if ( ( scalar @rows > 2 ) || ( grep { ref $_ ne 'ARRAY' } @rows ) ) {
				die "\"$err\" is an array of one error per bar, or of two such arrays (lower, then upper), in $current_sub";
			}
			foreach my $row (@rows) {
				if ( scalar @{$row} != $n_bars ) {
					die "\"$err\" has " . scalar( @{$row} ) . " values in a row, but $current_sub has $n_bars bars";
				}
				check_numbers( $row, "\"$err\"", $current_sub );
			}
			my @py = map { '[' . py_nums( @{$_} ) . ']' } @rows;
			$options .= ", $err = " . ( ( scalar @rows == 1 ) ? $py[0] : '[' . join( ',', @py ) . ']' );
		} elsif ( $ref eq 'HASH' ) {
			my @missing = grep { not defined $plot->{$err}{$_} } @key_order;
			if ( scalar @missing > 0 ) {
				p @missing;
				die "the above keys have no \"$err\" in $current_sub";
			}
			my ( @low, @high );
			foreach my $i (@key_order) {
				my $e    = $plot->{$err}{$i};
				my @pair = ( ref $e eq 'ARRAY' ) ? @{$e} : ( ref $e eq '' ) ? ( $e, $e ) : ();
				if ( scalar @pair != 2 ) {
					p $e;
					die "$err/$i should be one number, or exactly 2 items: low and high error bars";
				}
				check_numbers( \@pair, "\"$err\" of \"$i\"", $current_sub );
				push @low,  $pair[0];
				push @high, $pair[1];
			}
			$options .=
				 ", $err = [["
			  . py_nums(@low) . '],['
			  . py_nums(@high) . ']]';
		} else {
			p $args;
			die "$ref for $err isn't acceptable";
		}
	}
	if ( $plot_type eq 'simple' ) {    # a simple hash -> simple bar plot
		write_data({
			data => \@key_order,
			fh   => $args->{fh},
			name => 'labels'
		});
		say { $args->{fh} } 'vals = [' . py_nums( @{ $plot->{data} }{@key_order} ) . ']';
		if ((defined $plot->{color}) && (ref $plot->{color} eq 'HASH')) {
			@undef_args = grep {not defined $plot->{color}{$_}} @key_order;
			if (scalar @undef_args > 0) {
				p @undef_args;
				die 'the above keys were not defined in the colors hash';
			}
			$options .= ',color = [' . py_list( @{ $plot->{color} }{@key_order} ) . ']';
		}
		# "width" was read only by the grouped, stacked path, so a simple bar
		# plot was drawn at matplotlib's 0.8 whatever it said. barh calls the
		# same dimension "height".
		if ( defined $plot->{width} ) {
			$options .= ', ' . ( $plot->{plot_type} eq 'barh' ? 'height' : 'width' ) . ' = ' . py_num( $plot->{width} );
		}
		say { $args->{fh} } "ax$ax.$plot->{plot_type}(labels, vals $options)";
	} elsif ( $plot_type eq 'grouped' ) {    # grouped bar plot; hash of array
		my @val;
		foreach my $k (@key_order) {
			foreach my $i ( 0 .. scalar @{ $plot->{data}{$k} } - 1 ) {
				# 0 for a missing value, so that every series has a bar at
				# every key. Not written back: the array is the caller's.
				push @{ $val[$i] }, $plot->{data}{$k}[$i] // 0;
			}
		}
		my $barwidth = $plot->{width} // 0.8;
		if ( $plot->{stacked} == 0 ) {
			$barwidth /= ( scalar @val + 1 ); # @val holds one array per bar series
		}
		my @xticks   = 0 .. scalar @{ $val[0] } - 1;
		my @mean_pos = map { 0 } 0 .. scalar @{ $val[0] } - 1;    # initialize
		my $hw       = 'height';
		$hw = 'width' if $plot->{plot_type} eq 'bar';
		my @bottom = map { 0 } 0 .. scalar @{ $val[0] } - 1;      # initialize
		my $i = 0;
		foreach my $arr (@val) {
			my $x = '[' . join( ',', @xticks ) . ']';
			foreach my $p ( 0 .. $#mean_pos ) {
				$mean_pos[$p] += $xticks[$p];
			}
			my $set_options = '';
			foreach
			  my $f ( grep { ( ref $plot->{$_} eq 'ARRAY' ) && defined $plot->{$_}[$i] } ( 'color', 'label' ) )
			{
				 # py_str: a label is a series name, which for the
				 # hash-of-hashes form is one of the caller's own inner keys.
				 $set_options .= ", $f = " . py_str( $plot->{$f}[$i] );
			}
			if ( $plot->{stacked} > 0 ) {
				my $stack_kwarg = $plot->{plot_type} eq 'barh' ? 'left' : 'bottom';
				$set_options .= ", $stack_kwarg = [" . py_nums(@bottom) . ']';
			}
			say { $args->{fh} } "ax$ax.$plot->{plot_type}($x, ["
			 . py_nums( @{$arr} )
			 . "], $hw = " . py_num($barwidth) . " $options $set_options)";
			@bottom =
			  map { $bottom[$_] + $arr->[$_] } 0 .. scalar @{ $val[0] } - 1
			  if $plot->{stacked} > 0;
			@xticks = map { $_ + $barwidth } @xticks
			  if $plot->{stacked} <= 0;    # for next iteration
			  $i++;
		}
		my $xticks = '[' . py_list(@key_order) . ']';
		my $ticks  = 'yticks';
		$ticks = 'xticks' if $plot->{plot_type} eq 'bar';
		$_ /= scalar @val for @mean_pos;
		say { $args->{fh} } "ax$ax.set_$ticks(["
		 . join( ',', @mean_pos )
		 . "], $xticks)";
	} else {
	  die
	"\$plot_type = $plot_type & stacked = $plot->{stacked}and isn't defined.";
	}
}

sub boxplot_helper {
	my ($args) = @_;
	my $current_sub = ( split( /::/, ( caller(0) )[3] ) )[-1]
	; # https://stackoverflow.com/questions/2559792/how-can-i-get-the-name-of-the-current-subroutine-in-perl
	if ( ref $args ne 'HASH' ) {
		die "args must be given as a hash ref, e.g. \"$current_sub({ data => \@blah })\"";
	}
	my @reqd_args = (
	'fh',      # e.g. $py, $fh, which will be passed by the subroutine
	'plot',    # args to original function
	);
	my @undef_args = grep { !defined $args->{$_} } @reqd_args;
	if ( scalar @undef_args > 0 ) {
	  p @undef_args;
	  die 'the above args are necessary, but were not defined.';
	}
	my @opt = (
	  @ax_methods, @plt_methods, @fig_methods, @arg, 'ax', @{ $opt{$current_sub} }
	);
	my $plot      = $args->{plot};
	my @bad_opt = grep {
	  my $key = $_;
	  not grep { $_ eq $key } @opt
	} keys %{$plot};
	if ( scalar @bad_opt > 0 ) {
		bad_keyword_error({
			bad       => \@bad_opt,
			accepted  => \@opt,
			preferred => $opt{$current_sub},
			type      => $plot->{plot_type},
			sub       => $current_sub
		});
	}
	$plot->{orientation} = $plot->{orientation} // 'vertical';
	if ( $plot->{orientation} !~ m/^(?:horizontal|vertical)$/ ) {
	  die
	"$current_sub needs either \"horizontal\" or \"vertical\", not \"$plot->{orientation}\"";
	}
	if (ref $plot->{data} eq 'ARRAY') {
		my $tmp = delete $plot->{data};
		$plot->{data}{''} = $tmp;
	}
	my ( @xticks, @key_order );
	if ( defined $plot->{key_order} ) {
	  @key_order = check_key_order({
	  	keys   => $plot->{key_order},
	  	data   => $plot->{data},
	  	option => 'key_order',
	  	sub    => $current_sub
	  });
	} else {
	  @key_order = sort keys %{ $plot->{data} };
	}
	my $ax = $args->{ax} // '';
	$plot->{notch}      = $plot->{notch}      // 'False';
	$plot->{showcaps}   = $plot->{showcaps}   // 'True';
	$plot->{showfliers} = $plot->{showfliers} // 'True';
	$plot->{showmeans}  = $plot->{showmeans}  // 'True';
	my $options = "orientation = '$plot->{orientation}'";
	# Through bool_option, as bar's "log" is: each was written as given, so
	# "notch => 'false'" left "notch = false" in the script, a NameError.
	foreach my $arg ( 'showcaps', 'showfliers', 'showmeans', 'notch') {
	  $options .= ", $arg = " . ( bool_option( $plot->{$arg}, $arg, $current_sub ) ? 'True' : 'False' );
	}
	# A color per box is "colors"; "color" is one color for them all, and a
	# hash given here was written into the script as 'HASH(0x...)'.
	if ( ref $plot->{color} ) {
		die "\"color\" is one color for every box in $current_sub, not a " . ref( $plot->{color} ) . ' reference; give one color per key in "colors", e.g. colors => { A => \'red\' }';
	}
	foreach my $axis ( logscale_axes( $plot->{logscale}, $current_sub ) ) { # x, y
		say {$args->{fh}} "ax$ax.set_$axis" . 'scale("log")';
	}
	say { $args->{fh} } 'd = []';
	# %values, rather than writing the filtered list back into $plot->{data}:
	# the arrays in there belong to the caller, and dropping the undefined
	# elements in place left the caller's own array shorter than they wrote it.
	my %values;
	foreach my $key (@key_order) {
		@{ $values{$key} } = grep { ( defined ) && ( not is_nan($_) ) } @{ $plot->{data}{$key} };    # NaN is a missing value, as undef is
		my @non_numeric = grep {!looks_like_number($_)} @{ $values{$key} };
		if (scalar @non_numeric > 0) {
			p @non_numeric;
			die "$key has non-numeric values";
		}
		say { $args->{fh} } 'd.append([' . py_nums( @{ $values{$key} } ) . '])';
	}
	say { $args->{fh} } "bp = ax$ax.boxplot(d, patch_artist = True, $options)";
	if ( defined $plot->{colors} ){ # every hash key should have its own color defined
	# the below code helps to provide better error messages in case I make an error in calling the sub
		my @bad_keys =
		 grep { not defined $plot->{colors}{$_} } keys %{ $plot->{data} };
		if ( scalar @bad_keys > 0 ) {
			p @bad_keys;
			die 'the above data keys have no defined color';
		}

	# list of pre-defined colors: https://matplotlib.org/stable/gallery/color/named_colors.html
	  print { $args->{fh} } 'colors = ['
		 . py_list( @{ $plot->{colors} }{@key_order} ) . ']' . "\n";

	 # the above color list will have the same order, via the above hash slice
	  say { $args->{fh} } 'for patch, color in zip(bp["boxes"], colors):';
	  say { $args->{fh} } "\tpatch.set_facecolor(color)";
	  say { $args->{fh} } "\tpatch.set_edgecolor('black')";
	} else {
		say { $args->{fh} } 'for pc in bp["boxes"]:';
		if ( defined $plot->{color} ) {
			say { $args->{fh} } "\tpc.set_facecolor(" . py_str($plot->{color}) . ')';
		}
		say { $args->{fh} } "\tpc.set_edgecolor('black')";
	}
	foreach my $key (@key_order) {
		push @xticks, "$key ("
		 . format_commas( scalar @{ $values{$key} }, '%.0u' ) . ')';
	}
	if ( $plot->{orientation} eq 'vertical' ) {
		say { $args->{fh} } "ax$ax.set_xticks(["
		 . join( ',',   1 .. scalar @key_order ) . '], ['
		 . py_list(@xticks) . '])';
	} else {
		say { $args->{fh} } "ax$ax.set_yticks(["
		 . join( ',',   1 .. scalar @key_order ) . '], ['
		 . py_list(@xticks) . '])';
	}
}

sub table_cells {
	# The keys of a colored_table's rows and columns, in the order drawn, and
	# its cells, as ( \@row_keys, \@cols, \%data ). colored_table_helper draws
	# these, and shared_table_range scales the colors of several tables by
	# them, so that a cell "col_labels" leaves out of a table is left out of
	# the scale it shares as well.
	my ( $plot, $current_sub ) = @_;
	my $mirror = bool_option( $plot->{mirror}, 'mirror', $current_sub );
	# The rows and the columns. "data" is documented as outer key = row and
	# inner key = column, but both were taken from the outer keys, so a column
	# that was only ever an inner key was dropped: of
	# { H => { H => 432, Cl => 427 }, C => { H => 413, Cl => 339 } } the table
	# drew columns C and H, lost every Cl value and left the C column empty.
	# "col_labels" still selects the rows and the columns together, as
	# documented, and "mirror", which reflects the table, makes it square.
	my %inner;
	foreach my $k1 ( keys %{ $plot->{data} } ) {
		my $ref = ref $plot->{data}{$k1};
		if ( $ref ne 'HASH' ) {
			die "$current_sub takes a hash of hashes, but row \"$k1\" of \"data\" is " . ( $ref ? "a $ref reference" : 'a scalar' );
		}
		$inner{$_} = 1 foreach keys %{ $plot->{data}{$k1} };
	}
	my %every_key = ( %inner, map { $_ => 1 } keys %{ $plot->{data} } );
	my ( @row_keys, @cols, %data );
	if (defined $plot->{col_labels}) {
		@cols = check_key_order({
			keys   => $plot->{col_labels},
			data   => \%every_key,
			option => 'col_labels',
			sub    => $current_sub
		});
		@row_keys = @cols;
	} elsif ( $mirror ) {
		@row_keys = sort keys %every_key;
		@cols     = @row_keys;
	} else {
		@row_keys = sort keys %{ $plot->{data} };
		@cols     = sort keys %inner;
	}
	foreach my $k1 ( keys %{ $plot->{data} } ) {
		foreach my $k2 ( keys %{ $plot->{data}{$k1} } ) {
			$data{$k1}{$k2} = $plot->{data}{$k1}{$k2};
		}
	}
	# A reflection fills only the cells the caller left empty. It used to
	# overwrite, so where both $data{A}{B} and $data{B}{A} were given, which
	# one the table showed depended on hash order.
	if ( $mirror ) {
		foreach my $k1 ( keys %{ $plot->{data} } ) {
			foreach my $k2 ( keys %{ $plot->{data}{$k1} } ) {
				$data{$k2}{$k1} = $plot->{data}{$k1}{$k2} unless defined $data{$k2}{$k1};
			}
		}
	}
	return ( \@row_keys, \@cols, \%data );
}
sub colored_table_helper {
	my ($args) = @_;
	my $current_sub = (split(/::/,(caller(0))[3]))[-1]; # https://stackoverflow.com/questions/2559792/how-can-i-get-the-name-of-the-current-subroutine-in-perl
	if (ref $args ne 'HASH') {
		die "args must be given as a hash ref, e.g. \"$current_sub({ data => \@blah })\"";
	}
	my @reqd_args = (
		'fh',   # e.g. $py, $fh, which will be passed by the subroutine
		'plot', # args to original function
	);
	my @undef_args = grep {!defined $args->{$_}} @reqd_args;
	if (scalar @undef_args > 0) {
		p @undef_args;
		die "The arguments above are necessary for proper function of $current_sub and weren't defined.";
	}
#	optional args are below
	my @defined_args = (@reqd_args, @ax_methods, @plt_methods, @fig_methods, @arg,
	'ax', @{ $opt{$current_sub} });
	my @bad_args = grep { my $key = $_; not grep {$_ eq $key} @defined_args} keys %{ $args };
	if (scalar @bad_args > 0) {
		bad_keyword_error({
			bad      => \@bad_args,
			accepted => \@defined_args,
			sub      => $current_sub
		});
	}
	my $plot = $args->{plot};
#	The check above is on this sub's own arguments (fh, plot, ax), not on the
#	caller's plot keywords, which live one level down in "plot" and were going
#	unchecked here while every other helper checked its own.
	my @bad_opt = grep { my $key = $_; not grep {$_ eq $key} @defined_args} keys %{ $plot };
	if (scalar @bad_opt > 0) {
		bad_keyword_error({
			bad       => \@bad_opt,
			accepted  => \@defined_args,
			preferred => $opt{$current_sub},
			type      => $plot->{plot_type},
			sub       => $current_sub
		});
	}
	$plot->{mirror} = bool_option( $plot->{mirror}, 'mirror', $current_sub );
	my ( $row_keys, $cols, $cells ) = table_cells( $plot, $current_sub );
	my @row_keys = @{$row_keys};
	my @cols     = @{$cols};
	my %data     = %{$cells};
	my @rows;
	if (defined $plot->{row_labels}) {
		@rows = @{ $plot->{row_labels} };
		# matplotlib refuses a count that differs, with an error naming neither
		# option.
		if ( scalar @rows != scalar @row_keys ) {
			die "\"row_labels\" has " . scalar(@rows) . ' labels, but the table has ' . scalar(@row_keys) . " rows in $current_sub";
		}
	} else {
		@rows = @row_keys;
	}
	my ($min, $max) = ('inf', '-inf');
	my $min_positive = 'inf';    # the floor of a log scale, which cannot start at 0 or below
	my $n_numeric = 0;    # cells that hold a number, for the check below
	say {$args->{fh}} 'd = []';
	say {$args->{fh}} 'import numpy as np';
	# What a cell with no value in "data" gets. np.nan, which a NaN cell also
	# becomes, is drawn in "undef_color" by the colormap's set_bad below and
	# left blank by "show_numbers"; a "default_undefined" given by the caller
	# is an ordinary value instead, counting towards the color scale like any
	# other. The option was read and then ignored -- the line below assigned
	# np.nan with "$plot->{default_undefined}" commented out beside it -- so a
	# table asked to call its holes 0 still drew them as holes.
	if (defined $plot->{default_undefined}) {
		unless (looks_like_number($plot->{default_undefined})) {
			die "\"default_undefined\" = $plot->{default_undefined} must be a number";
		}
	}
	# A cell that holds something other than a number is written into the
	# script as it stands, so "NA" became "d.append([1,NA])" and died as a
	# NameError. Checked before anything is written.
	my @non_numeric;
	foreach my $k1 (@row_keys) {
		foreach my $k2 (grep { (defined $data{$k1}{$_}) && (not looks_like_number($data{$k1}{$_})) } @cols) {
			push @non_numeric, "$k1/$k2 = \"$data{$k1}{$k2}\"";
		}
	}
	if (scalar @non_numeric > 0) {
		p @non_numeric;
		die "the above cells are not numbers, which $current_sub needs; leave a cell out, or undefined, to draw it in \"undef_color\"";
	}
	foreach my $k1 (@row_keys) {
		my @cells;
		foreach my $k2 (@cols) {
			my $value = $data{$k1}{$k2} // $plot->{default_undefined};
			push @cells, defined $value ? py_num($value) : 'np.nan';
			# A NaN or an infinity is drawn, but cannot be an end of the scale.
			next unless ( defined $value ) && is_finite($value);
			$min = min($min, $value);
			$max = max($max, $value);
			$min_positive = min($min_positive, $value) if $value > 0;
			$n_numeric++;
		}
		say {$args->{fh}} 'd.append([' . join( ',', @cells ) . '])';
	}
	# Nothing to scale the colors by. $min and $max are still the strings they
	# started as, and "plt.Normalize(inf, -inf)" is a NameError in Python,
	# which said nothing about the table being empty.
	if (($n_numeric == 0) && ((not defined $plot->{cb_min}) || (not defined $plot->{cb_max}))) {
		p $plot->{data};
		die "no cell of the above data holds a number, so $current_sub has nothing to color by";
	}
	foreach my $opt (grep {defined $plot->{$_}} 'cb_min', 'cb_max'){
		unless (looks_like_number( $plot->{$opt} )) {
			die "\"$opt\" = $plot->{$opt} must be a number";
		}
		# An end of the scale at infinity leaves no finite range to color by.
		die "\"$opt\" = $plot->{$opt} must be a finite number" unless is_finite( $plot->{$opt} );
	}
	$plot->{cmap} = $plot->{cmap} // 'gist_rainbow';
	$plot->{cb_logscale} = bool_option( $plot->{cb_logscale}, 'cb_logscale', $current_sub );
	my $ax = $args->{ax} // '';
	# One norm, used both to color the cells and by the hidden image that the
	# colorbar is drawn from. The cells used to be colored through a linear
	# plt.Normalize whatever "cb_logscale" said, so only the colorbar was
	# logarithmic, and a table of 1, 10, 100 and 1000 drew three of its four
	# cells in nearly the same color.
	my $norm;
	if ($plot->{cb_logscale}) {
		# LogNorm refuses a vmin at or below 0; the one it chose for itself,
		# when it was left to autoscale, was the smallest positive value.
		$min = $plot->{cb_min} // $min_positive;
		if ($min eq 'inf') {
			die "\"cb_logscale\" needs a cell above 0 to start the scale at, or a \"cb_min\" above 0, and $current_sub has neither";
		}
		if ($min <= 0) {
			die "\"cb_logscale\" cannot start at \"cb_min\" = $min: a log scale needs a minimum above 0";
		}
		$max = $plot->{cb_max} // $max;
		say {$args->{fh}} 'from matplotlib import colors';
		$norm = 'colors.LogNorm(vmin = ' . py_num($min) . ', vmax = ' . py_num($max) . ')';
	} else {
		$min = $plot->{cb_min} // $min;
		$max = $plot->{cb_max} // $max;
		$norm = 'plt.Normalize(' . py_num($min) . ', ' . py_num($max) . ')';    # py_num: a cb_min such as "007" was written as given
	}
	$plot->{undef_color} = $plot->{undef_color} // 'gray';
	say {$args->{fh}} 'import matplotlib';
	say {$args->{fh}} 'table_cmap = matplotlib.colormaps[' . py_str($plot->{cmap}) . '].copy()';
	say {$args->{fh}} 'table_cmap.set_bad(' . py_str($plot->{undef_color}) . ')';
	say {$args->{fh}} "norm = $norm";
	say {$args->{fh}} 'datacolors = table_cmap(norm(d))';
	say {$args->{fh}} "img = ax$ax.imshow(d, cmap=table_cmap, norm=norm)";
	$plot->{colorbar_on} = bool_option( $plot->{colorbar_on} // 1, 'colorbar_on', $current_sub );
	# "colorbar_on" decides, and "cblabel" only says what to write on it. A
	# cblabel used to draw the colorbar even against "colorbar_on => 0",
	# which the documentation recorded rather than fixed: nobody passes a label
	# for a colorbar they have just turned off, so it read as a typo that the
	# module honoured.
	if ($plot->{colorbar_on}) {
		# colorbar_args: the cb* options, documented as working here, were
		# accepted and never written.
		my $label = defined $plot->{cblabel} ? ', label = ' . py_str($plot->{cblabel}) : '';
		say {$args->{fh}} "fig.colorbar(img$label" . colorbar_args($plot) . ')';
	}
	say {$args->{fh}} 'img.set_visible(False)';
	$plot->{show_numbers} = bool_option( $plot->{show_numbers}, 'show_numbers', $current_sub );
	say {$args->{fh}} 'for ri, row in enumerate(d):';
	say {$args->{fh}} '	for ii, item in enumerate(row):';
	say {$args->{fh}} '		if np.isnan(item):';
	say {$args->{fh}} '			d[ri][ii] = ""';
	if ($plot->{show_numbers}) {
		say {$args->{fh}} "table = ax$ax" . '.table(cellText=d, rowLabels=[' . py_list(@rows) . '], colLabels = [' . py_list(@cols) . '], cellColours = datacolors, loc = "center", bbox=[0,0,1,1])';
	} else {
		say {$args->{fh}} "table = ax$ax" . '.table(rowLabels=[' . py_list(@rows) . '], colLabels = [' . py_list(@cols) . '], cellColours = datacolors, loc = "center", bbox=[0,0,1,1])';
	}
	# No title written here, though there was one: it emitted "ax0.title('..')",
	# and "title" is a Text attribute of the axes rather than a method, so a
	# colored_table given a title died with "TypeError: 'Text' object is not
	# callable". plt() renames "title" to "set_title" for every plot type once
	# its helper has run, which is what actually draws it.
	# No logscale loop here, though there was one: "logscale" is not among the
	# options colored_table accepts, so the loop could never run, and a log
	# scale would mean nothing on a table whose axes are the row and column
	# labels -- both sets of ticks are emptied a few lines below.
#	say {$args->{fh}} "fig.clim(vmin = $plot->{cb_min})" if defined $plot->{cb_min};
#	say {$args->{fh}} "fig.clim(vmax = $plot->{cb_max})" if defined $plot->{cb_max};
	foreach my $axis ('x','y') {
		say {$args->{fh}} "ax$ax.set_${axis}ticks" . '([])';
		say {$args->{fh}} "ax$ax.set_${axis}ticklabels" . '([])';
	}
}

sub hexbin_helper {
	my ($args) = @_;
	my $current_sub = ( split( /::/, ( caller(0) )[3] ) )[-1]
	; # https://stackoverflow.com/questions/2559792/how-can-i-get-the-name-of-the-current-subroutine-in-perl
	if ( ref $args ne 'HASH' ) {
		die "args must be given as a hash ref, e.g. \"$current_sub({ data => \@blah })\"";
	}
	my @reqd_args = (
		'fh',      # e.g. $py, $fh, which will be passed by the subroutine
		'plot',    # args to original function
	);
	my @undef_args = grep { !defined $args->{$_} } @reqd_args;
	if ( scalar @undef_args > 0 ) {
		p @undef_args;
		die 'the above args are necessary, but were not defined.';
	}
	my @opt = (
	  @ax_methods, @fig_methods, @arg, @plt_methods,
	  'ax', @{ $opt{$current_sub} }
	);
	my $plot = $args->{plot};
	@undef_args = grep {
	  my $key = $_;
	  not grep { $_ eq $key } @opt
	} keys %{$plot};
	if ( scalar @undef_args > 0 ) {
		bad_keyword_error({
			bad       => \@undef_args,
			accepted  => \@opt,
			preferred => $opt{$current_sub},
			type      => $plot->{plot_type},
			sub       => $current_sub
		});
	}
	cb_limits( $plot, $current_sub );
	$plot->{cb_logscale} = bool_option( $plot->{cb_logscale}, 'cb_logscale', $current_sub );
	$plot->{marginals}   = $plot->{marginals}   // 0;
	bin_counts( $plot, $current_sub );
	my @keys;
	if ( defined $plot->{key_order} ) {
		@keys = check_key_order({
			keys   => $plot->{key_order},
			data   => $plot->{data},
			option => 'key_order',
			sub    => $current_sub
		});
	} else {
		@keys = sort keys %{ $plot->{data} };
	}
	if ( scalar @keys != 2 ) {
	  p @keys;
	  die "There must be exactly 2 keys for $current_sub";
	}
	my $n_points = scalar @{ $plot->{data}{ $keys[0] } };
	if ( scalar @{ $plot->{data}{ $keys[1] } } != $n_points ) {
	  say STDERR "\"$keys[0]\" has $n_points points.";
	  say STDERR "\"$keys[1]\" has "
		 . scalar @{ $plot->{data}{ $keys[1] } }
		 . " points.";
	  die 'The length of both keys must be equal.';
	}
	# Every point is written into the script as it stands, and nothing checked
	# them: an undefined one came out as an empty list element and a string
	# as a bare python name, each dying as a python error about the temp file.
	foreach my $key (@keys) {
		my @bad = grep { not looks_like_number( $plot->{data}{$key}[$_] ) } 0 .. $n_points - 1;
		next if scalar @bad == 0;
		p @bad;
		die "\"$key\" is undefined or not a number at the above indices, which $current_sub needs";
	}
	# quoted here because the key is data: the pass-through path that title and
	# label text otherwise take cannot tell an apostrophe from Python of the
	# user's own, and leaves it bare. See py_str.
	default_axis_labels( $plot, @keys );
	$plot->{cmap}   = $plot->{cmap}   // 'gist_rainbow';
	my $options =
	", gridsize = ($plot->{xbins}, $plot->{ybins}), cmap = " . py_str($plot->{cmap})
	;    # these args go to the plt.hist call
	foreach my $opt ( grep { defined $plot->{$_} } ( 'vmin', 'vmax', 'mincnt' ) ) {
		if ( not looks_like_number( $plot->{$opt} ) ) {
			die "\"$opt\" must be a number for $current_sub, but was given \"$plot->{$opt}\"";
		}
	}
	# A log scale cannot start at 0 or below, which LogNorm refused from inside
	# matplotlib, naming neither option.
	if ( ( $plot->{cb_logscale} ) && ( defined $plot->{vmin} ) && ( $plot->{vmin} <= 0 ) ) {
		die "\"cb_logscale\" cannot start at \"vmin\" = $plot->{vmin} in $current_sub: a log scale needs a minimum above 0";
	}
	# py_num, here and below: each was written as given, so "vmax => 'inf'",
	# which looks_like_number accepts, was a NameError in the script.
	if ( $plot->{cb_logscale} ) {
		# vmin and vmax go to the LogNorm, as in hist2d_helper: passed beside
		# it they raised "ValueError: Passing a Normalize instance
		# simultaneously with vmin/vmax is not supported".
		say { $args->{fh} } 'from matplotlib.colors import LogNorm';
		my @lognorm_opt = map { "$_ = " . py_num( $plot->{$_} ) } grep { defined $plot->{$_} } ( 'vmin', 'vmax' );
		$options .= ', norm = LogNorm(' . join( ', ', @lognorm_opt ) . ')';
		foreach my $opt ( grep { defined $plot->{$_} } ('mincnt') ) {
			$options .= ", $opt = " . py_num( $plot->{$opt} );
		}
	} else {
		foreach my $opt ( grep { defined $plot->{$_} } ( 'vmin', 'vmax', 'mincnt' ) ) {
			$options .= ", $opt = " . py_num( $plot->{$opt} );
		}
	}
	foreach my $opt (grep {defined $plot->{$_} } ('xscale_hexbin', 'yscale_hexbin')) {
		if (($plot->{$opt} ne 'log') && ($plot->{$opt} ne 'linear')) {
			die "\"$opt\" is neither \"log\" nor \"linear\"";
		}
		my $opth = $opt;
		$opth =~ s/_hexbin$//;    # "xscale_hexbin" is hexbin's own "xscale"
		$options .= ", $opth = '$plot->{$opt}'";
	}
	if ( bool_option( $plot->{marginals}, 'marginals', $current_sub ) ) {
		$options .= ', marginals = True';
	}
	say { $args->{fh} } 'x = ['
	. py_nums( @{ $plot->{data}{ $keys[0] } } ) . ']';
	say { $args->{fh} } 'y = ['
	. py_nums( @{ $plot->{data}{ $keys[1] } } ) . ']';
	my $ax = $args->{ax} // '';
	say { $args->{fh} } "im$ax = ax$ax.hexbin(x, y $options)\n";
	my $opts = colorbar_args($plot);    # cblabel is written below
	# "colorbar_on" is read here, and not only for the shared-colorbar test
	# above: the colorbar was drawn whatever it said, so "colorbar_on => 0"
	# did nothing, and a figure sharing one colorbar between subplots got the
	# shared one *and* the per-subplot one plt() had asked to be turned off.
	if ( $plot->{colorbar_on} ) {
		if ( defined $plot->{cblabel} ) {
			write_data({
				data => $plot->{cblabel},
				fh   => $args->{fh},
				name => 'cblabel',
			});
			say { $args->{fh} } "plt.colorbar(im$ax, label = cblabel $opts)";
		} else {
			say { $args->{fh} } "plt.colorbar(im$ax, label = 'Density' $opts)";
		}
	}
}

sub bin_counts {
	# "xbins" and "ybins" for hexbin and hist2d, each a whole number of at
	# least 1, set to its default of 15 where not given.
	#
	# Only 0 was refused. A negative count reached numpy, which refused it as
	# "'minlength' must not be negative", and a word died at int() as
	# 'Argument "ten" isn't numeric'.
	my ( $plot, $current_sub ) = @_;
	foreach my $bins ( 'xbins', 'ybins' ) {
		$plot->{$bins} = $plot->{$bins} // 15;
		my $n = $plot->{$bins};
		if ( ( ref $n ) || ( not looks_like_number($n) ) || ( not is_finite($n) ) || ( int($n) < 1 ) ) {
			die "\"$bins\" must be a whole number of at least 1 for $current_sub, not \"$n\"";
		}
		$plot->{$bins} = int $n;
	}
}
sub colorbar_args {
	# The keyword arguments of a colorbar call that the cb* options and
	# "shared_colorbar" ask for, each led by ", ". "cblabel" is left to the
	# caller, since each helper has a default label of its own.
	#
	# hexbin, hist2d and imshow each wrote this out for themselves; scatter
	# and colored_table accepted the same options and wrote none of them.
	# Sets "colorbar_on" to its default, 1, as each of those did.
	my ($plot) = @_;
	my $opts = '';
	foreach my $o (grep {defined $plot->{$_}} ('cblocation', 'cborientation')) { # str
		my $mpl_opt = $o;
		$mpl_opt =~ s/^cb//;
		$opts .= ", $mpl_opt = " . py_str( $plot->{$o} );
	}
	foreach my $o (grep {defined $plot->{$_}} ('cbdrawedges', 'cbpad')) { # numeric
		die "$o = $plot->{$o} must be numeric" unless (looks_like_number($plot->{$o}));
		my $mpl_opt = $o;
		$mpl_opt =~ s/^cb//;
		$opts .= ", $mpl_opt = " . py_num( $plot->{$o} );
	}
	# Read as a Python bool: tested for Perl truth, "colorbar_on => 'False'"
	# drew the colorbar.
	$plot->{colorbar_on} = bool_option( $plot->{colorbar_on} // 1, 'colorbar_on', "plot_type \"" . ( $plot->{plot_type} // '' ) . '"' );
	if (($plot->{colorbar_on}) && (defined $plot->{shared_colorbar})) {
		my @ax = map {"ax$_"} @{ $plot->{shared_colorbar} };
		$opts .= ', ax = [' . join (',', @ax) . '] ';
	}
	return $opts;
}
sub format_commas
{ #($n, $format = '.%02d') { # https://stackoverflow.com/questions/33442240/perl-printf-to-use-commas-as-thousands-separator
    # $format should be '%.0u' for integers
    my ( $n, $format ) = @_;
    $format = '.%02d' if not defined $format;
    return
      reverse( join( ",", unpack( "(A3)*", reverse int($n) ) ) )
      . sprintf( $format, int( 100 * ( .005 + ( $n - int($n) ) ) ) );
}

sub hist_value {
	# A scalar "bins", "color" or "orientation" for hist(), as python.
	#
	# A number of bins is the one bare value; everything else is text. The
	# test this replaces quoted only /^[A-Za-z]+$/, so a color such as
	# "#ff0000" went in bare and python read the rest of the line as a comment,
	# and "tab:blue" or a grayscale "0.5" went in as python rather than as a
	# color.
	my ( $arg, $value ) = @_;
	return py_num($value) if ( $arg eq 'bins' ) && looks_like_number($value);    # py_num: "010" bins was a SyntaxError
	return py_str($value);
}
sub hist_helper {
	my ($args) = @_;
	my $current_sub = ( split( /::/, ( caller(0) )[3] ) )[-1]
	; # https://stackoverflow.com/questions/2559792/how-can-i-get-the-name-of-the-current-subroutine-in-perl
	if ( ref $args ne 'HASH' ) {
		die
	"args must be given as a hash ref, e.g. \"$current_sub({ data => \@blah })\"";
	}
	my @reqd_args = (
		'ax',   # used for multiple plots
		'fh',   # e.g. $py, $fh, which will be passed by the subroutine
		'plot', # args to original function
	);
	my @undef = grep { !defined $args->{$_} } @reqd_args;
	if ( scalar @undef > 0 ) {
		p @undef;
		die 'the above args are necessary, but were not defined.';
	}
	my @opt = (@ax_methods, @plt_methods, @fig_methods, @arg, 'ax', @{ $opt{$current_sub} });
	my $plot      = $args->{plot};
	@undef = grep {
		my $key = $_;
		not grep { $_ eq $key } @opt
	} keys %{$plot};
	if ( scalar @undef > 0 ) {
		bad_keyword_error({
			bad       => \@undef,
			accepted  => \@opt,
			preferred => $opt{$current_sub},
			type      => $plot->{plot_type},
			sub       => $current_sub
		});
	}
	my $options = '';    # these args go to the plt.hist call
	$plot->{alpha} = $plot->{alpha} // 0.5;
	check_numbers( [ $plot->{alpha} ], '"alpha"', $current_sub );    # written into every hist() call
	# Through py_num: "alpha => 'nan'" passes looks_like_number and was written
	# as given, a NameError in the script.
	my $alpha = py_num( $plot->{alpha} );
	# All the sets are drawn on one axes, so they share one orientation. A hash
	# was skipped as though it held a setting per set, and then never read.
	if ( ref $plot->{orientation} ) {
		die "\"orientation\" is one of \"vertical\" or \"horizontal\" for every set in $current_sub, not a " . ref( $plot->{orientation} ) . ' reference';
	}
	# "color" is here as well as below: a single color for every set was
	# accepted and then never written, since only the per-set hash was read.
	foreach my $arg ( grep { defined $plot->{$_} } ( 'bins', 'color', 'orientation' ) ) {
		next if ref $plot->{$arg} eq 'HASH';    # set-specific setting exists
		my $ref = ref $plot->{$arg};
		if ( $ref eq '' ) {
			$options .= ", $arg = " . hist_value( $arg, $plot->{$arg} );
		} elsif ( $arg eq 'color' ) {
			# hist() is called once per set, so there is no position in a list
			# of colors that means a set; the hash names them.
			die "\"color\" for $current_sub is one color for every set, or a hash of one color per set, not a $ref reference";
		} elsif ( $ref eq 'ARRAY' ) {
			$options .= ", $arg = [" . py_nums( @{ $plot->{$arg} } ) . ']';
		} else {
			p $plot;
			die "$ref for $arg isn't acceptable";
		}
	}
	foreach my $axis ( logscale_axes( $plot->{logscale}, $current_sub ) ) { # x, y
		say {$args->{fh}} "ax$args->{ax}.set_$axis" . 'scale("log")';
	}
	if (ref $plot->{data} eq 'ARRAY') {
		my $tmp = delete $plot->{data};
		$plot->{data}{A} = $tmp;
	}
	# A per-set "bins" or "color" keyed by a set that is not in "data" -- a
	# typo, most often -- was ignored, and that set drawn with the defaults.
	foreach my $arg ( grep { ref $plot->{$_} eq 'HASH' } ( 'bins', 'color' ) ) {
		my @stray = sort grep { not exists $plot->{data}{$_} } keys %{ $plot->{$arg} };
		next if scalar @stray == 0;
		p @stray;
		die "the above keys of \"$arg\" are not sets of \"data\" in $current_sub";
	}
	# The order the sets are drawn in, and so the order of the legend. Sorted
	# by name before, with no way to change it, so the groups that "df" makes
	# with "by" came out with 10 before 2, though the documentation promised
	# numeric order.
	my @key_order;
	if ( defined $plot->{key_order} ) {
		@key_order = check_key_order({
			keys   => $plot->{key_order},
			data   => $plot->{data},
			option => 'key_order',
			sub    => $current_sub
		});
	} else {
		@key_order = sort keys %{ $plot->{data} };
	}
	if (scalar keys %{ $plot->{data} } > 1) {
		$plot->{show_legend} = bool_option( $plot->{show_legend} // 1, 'show_legend', $current_sub );
	} else {
		$plot->{show_legend} = bool_option( $plot->{show_legend} // 0, 'show_legend', $current_sub );
	}
	# Every bin height drawn into this subplot goes into hist_counts<ax>, for
	# the range that plt() reports once the subplot is drawn; see
	# hist_range_report. Named for the subplot because a figure's subplots all
	# write into the one script, in order, and each has to report its own range.
	foreach my $set (@key_order) {
		my @non_numeric = grep {not looks_like_number($_)} @{ $plot->{data}{$set} };
		if (scalar @non_numeric > 0) {
			p @non_numeric;
			die "$set has non-numeric values; which for hist must be numeric";
		}
		# NaN is left for matplotlib, which bins around it; an infinity leaves it
		# no finite range to bin, and died as "supplied range of [1.0, inf] is not
		# finite".
		my @infinite = grep { not ( is_nan($_) || is_finite($_) ) } @{ $plot->{data}{$set} };
		if (scalar @infinite > 0) {
			p @infinite;
			die "$set has the above infinite values, which $current_sub cannot bin";
		}
		my $set_options = '';
		foreach
		 my $arg ( grep { ref $plot->{$_} eq 'HASH' } ( 'bins', 'color' ) )
		{
			next unless defined $plot->{$arg}{$set};
			my $ref = ref $plot->{$arg}{$set};
			if ( ( $ref eq 'ARRAY' ) && ( $arg eq 'color' ) ) {
				die "\"color\" for set \"$set\" is an array, but $current_sub draws each set in one color";
			} elsif ( $ref eq 'ARRAY' ) {
				# Bin edges for this set alone. The whole-plot "bins" has taken
				# an array since it was written; per set it fell through to the
				# single-value branch below and emitted "bins = ARRAY(0x55f0...)".
				$set_options .= ", $arg = [" . py_nums( @{ $plot->{$arg}{$set} } ) . ']';
			} elsif ( $ref ne '' ) {
				p $plot->{$arg};
				die "\"$arg\" for set \"$set\" is a $ref reference, but $current_sub takes a scalar or an array there";
			} else {
				$set_options .= ", $arg = " . hist_value( $arg, $plot->{$arg}{$set} );
			}
		}
		say {$args->{fh}} 'd = [' . py_nums( @{ $plot->{data}{$set} } ) . ']';
		# hist() returns (counts, bin edges, patches); the counts are the only
		# way to know a bin's height, since matplotlib, not this module, does
		# the binning. Naming them changes nothing about what is drawn.
		if ($plot->{show_legend}) {
			say { $args->{fh} } "hist_n, hist_edges, hist_patches = ax$args->{ax}.hist(d, alpha = $alpha, label = " . py_str($set) . " $options $set_options)";
		} else {
			say { $args->{fh} } "hist_n, hist_edges, hist_patches = ax$args->{ax}.hist(d, alpha = $alpha $options $set_options)";
		}
		say {$args->{fh}} "hist_counts$args->{ax} += list(hist_n)";
	}
}
sub has_hist {
	# Whether a plot, or one of its "add" graphs, is a hist. An "add" graph
	# with no "plot_type" of its own takes $type, the plot's.
	my ( $plot, $type ) = @_;
	my @graphs = ( $plot, ( ref $plot->{add} eq 'ARRAY' ) ? @{ $plot->{add} } : () );
	return scalar grep { ( ref $_ eq 'HASH' ) && ( ( $_->{plot_type} // $type // '' ) eq 'hist' ) } @graphs;
}
sub hist_range_report {
	# Python that starts ($when = 'start') or reports ($when = 'report') the
	# range of the bin heights of every hist drawn into subplot $ax.
	#
	# plt() calls this around the whole subplot -- its "add" graphs and its own
	# plot -- rather than hist_helper around each hist, which reset the list for
	# each: a subplot with a hist overlay printed two ranges, the second
	# leaving out the overlay's bins, where one range over all its sets is
	# what the documentation promises.
	#
	# On STDOUT and nowhere else: nothing here is handed to matplotlib, so the
	# figure written to "output_file" is exactly what it was without this.
	# plt() prints the script's STDOUT back out.
	my ( $fh, $ax, $when ) = @_;
	if ( $when eq 'start' ) {
		say {$fh} "hist_counts$ax = []";
		return;
	}
	# "%g" because hist() hands back its counts as float64, and "[1, 12]" for a
	# tally of whole things is what was counted; "[1.0, 12.0]" reads as though
	# it were not.
	# An empty subplot has no bins at all, and min() of an empty list raises
	# ValueError, so there is nothing to report.
	say {$fh} "if len(hist_counts$ax) > 0:";
	say {$fh} "\tprint(f'plot $ax hist range = [{min(hist_counts$ax):g}, {max(hist_counts$ax):g}]')";
}

sub hist2d_helper {
	my ($args) = @_;
	my $current_sub = ( split( /::/, ( caller(0) )[3] ) )[-1]
	; # https://stackoverflow.com/questions/2559792/how-can-i-get-the-name-of-the-current-subroutine-in-perl
	if ( ref $args ne 'HASH' ) {
		die "args must be given as a hash ref, e.g. \"$current_sub({ data => \@blah })\"";
	}
	my @reqd_args = (
		'fh',      # e.g. $py, $fh, which will be passed by the subroutine
		'plot',    # args to original function
	);
	my @undef_args = grep { !defined $args->{$_} } @reqd_args;
	if ( scalar @undef_args > 0 ) {
	  p @undef_args;
	  die 'the above args are necessary, but were not defined.';
	}
	my @opt = (@ax_methods, @plt_methods, @fig_methods, @arg, 'ax', @{ $opt{$current_sub} });
	my $plot = $args->{plot};
	@undef_args = grep {
	  my $key = $_;
	  not grep { $_ eq $key } @opt
	} keys %{$plot};
	if ( scalar @undef_args > 0 ) {
		bad_keyword_error({
			bad       => \@undef_args,
			accepted  => \@opt,
			preferred => $opt{$current_sub},
			type      => $plot->{plot_type},
			sub       => $current_sub
		});
	}
	cb_limits( $plot, $current_sub );
	$plot->{cb_logscale}     = bool_option( $plot->{cb_logscale}, 'cb_logscale', $current_sub );
	$plot->{show_colorbar} = bool_option( $plot->{show_colorbar} // 1, 'show_colorbar', $current_sub );
	bin_counts( $plot, $current_sub );
	my @keys;
	if ( defined $plot->{key_order} ) {
		@keys = check_key_order({
			keys   => $plot->{key_order},
			data   => $plot->{data},
			option => 'key_order',
			sub    => $current_sub
		});
	} else {
		@keys = sort keys %{ $plot->{data} };
	}
	if ( scalar @keys != 2 ) {
	  p @keys;
	  die "There must be exactly 2 keys for $current_sub";
	}
	my $n_points = scalar @{ $plot->{data}{ $keys[0] } };
	if ( scalar @{ $plot->{data}{ $keys[1] } } != $n_points ) {
	  say STDERR "$keys[0] has $n_points points.";
	  say STDERR "$keys[1] has "
		 . scalar @{ $plot->{data}{ $keys[1] } }
		 . " points.";
	  die 'The length of both keys must be equal.';
	}
	# quoted here because the key is data: the pass-through path that title and
	# label text otherwise take cannot tell an apostrophe from Python of the
	# user's own, and leaves it bare. See py_str.
	default_axis_labels( $plot, @keys );
	$plot->{cmap}   = $plot->{cmap}   // 'gist_rainbow';
	my $options = ', cmap = ' . py_str($plot->{cmap}); # these args go to the plt.hist call
	if ( $plot->{cb_logscale} ) {
		say {$args->{fh}} 'from matplotlib.colors import LogNorm';
		# prevents "ValueError: Passing a Normalize instance simultaneously with vmin/vmax is not supported.  Please pass vmin/vmax directly to the norm when creating it"
		my @logNorm_opt;
		foreach my $arg (grep {defined $plot->{$_}} ('vmin', 'vmax')) {
			if (not looks_like_number($plot->{$arg})) {
				die "$arg must be numeric for $current_sub, but was given \"$plot->{$arg}\"";
			}
			if ( ( $arg eq 'vmin' ) && ( $plot->{$arg} <= 0 ) ) {    # as in hexbin_helper
				die "\"cb_logscale\" cannot start at \"vmin\" = $plot->{$arg} in $current_sub: a log scale needs a minimum above 0";
			}
			push @logNorm_opt, "$arg = " . py_num( $plot->{$arg} );    # py_num: "vmax => 'inf'" was a NameError
			delete $plot->{$arg}; 
		}
		$options .= ', norm = LogNorm(' . join (',', @logNorm_opt) . ')';
	}
	# Checked here as the log-scale branch above checks its own: each was
	# written as given, so "vmin => 'low'" left "vmin = low" in the script.
	foreach my $opt ( grep { defined $plot->{$_} } ( 'cmin', 'cmax', 'vmin', 'vmax' ) ) {
		check_numbers( [ $plot->{$opt} ], "\"$opt\"", $current_sub );
		$options .= ", $opt = " . py_num( $plot->{$opt} );
	}
	if ( defined $plot->{density} ) {
		$options .= ', density = ' . ( bool_option( $plot->{density}, 'density', $current_sub ) ? 'True' : 'False' );
	}
	my @bad_indices;
	my $bad_pts = 0;
	foreach my $i (0,1) {
		@{ $bad_indices[$i] } = grep {not defined $plot->{data}{$keys[$i]}[$_]} 0..$n_points-1;
		$bad_pts += scalar @{ $bad_indices[$i] };
	}
	if ($bad_pts > 0) {
		say STDERR "the above args have the following indices undefined ($n_points total)";
		p @bad_indices;
		die "Cannot proceed as there are $bad_pts undefined points.";
	}
	foreach my $i (0,1) {
		@{ $bad_indices[$i] } = grep {not looks_like_number($plot->{data}{$keys[$i]}[$_])} 0..$n_points-1;
		$bad_pts += scalar @{ $bad_indices[$i] };
	}
	if ($bad_pts > 0) {
		p $args;
		say STDERR "the above args have the following indices non-numeric ($n_points total)";
		p @bad_indices;
		die "Cannot proceed as there are $bad_pts non-numeric points.";
	}
	say { $args->{fh} } 'x = ['
	. py_nums( @{ $plot->{data}{ $keys[0] } } ) . ']';
	say { $args->{fh} } 'y = ['
	. py_nums( @{ $plot->{data}{ $keys[1] } } ) . ']';
	# The ends of the range binned over, each the caller's or the data's own.
	# Nothing here was checked, and each was written as given: "xmin => 'a'"
	# was a NameError, a column with no finite value left an undefined end that
	# died as "Use of uninitialized value in concatenation", and a log axis
	# that reached 0 died inside np.log10 as "invalid entry in coordinates
	# array".
	my %log_axis = map { $_ => 1 } logscale_axes( $plot->{logscale}, $current_sub );
	foreach my $i ( 0, 1 ) {
		my $axis   = ( 'x', 'y' )[$i];
		my @finite = finite_values( @{ $plot->{data}{ $keys[$i] } } );
		foreach my $end ( 'min', 'max' ) {
			my $opt = "$axis$end";
			if ( defined $plot->{$opt} ) {
				check_numbers( [ $plot->{$opt} ], "\"$opt\"", $current_sub );
				die "\"$opt\" must be a finite number for $current_sub, not \"$plot->{$opt}\"" unless is_finite( $plot->{$opt} );
			} elsif ( scalar @finite == 0 ) {
				die "\"$keys[$i]\" has no finite value, so $current_sub has no range to bin it over; give \"${axis}min\" and \"${axis}max\"";
			} else {
				$plot->{$opt} = ( $end eq 'min' ) ? min(@finite) : max(@finite);
			}
		}
		my ( $lo, $hi ) = @{$plot}{ "${axis}min", "${axis}max" };
		if ( $lo > $hi ) {
			die "\"${axis}min\" = $lo is above \"${axis}max\" = $hi in $current_sub";
		}
		if ( ( $log_axis{$axis} ) && ( $lo <= 0 ) ) {
			die "\"logscale\" puts $axis on a log scale, which cannot start at $lo in $current_sub: give a \"${axis}min\" above 0";
		}
	}
	my %end = map { $_ => py_num( $plot->{$_} ) } ( 'xmin', 'xmax', 'ymin', 'ymax' );
	my $ax = $args->{ax} // '';
	# the range argument ensures that there are no empty parts of the plot
	my $range =	", range = [($end{xmin}, $end{xmax}), ($end{ymin}, $end{ymax})]";
	# logscale complications
	say {$args->{fh}} 'import numpy as np';
	# Bin edges, one more than the bins: "xbins" and "ybins" count bins, as
	# they do on a linear plot, where they go to hist2d as counts. They were
	# written as the number of edges, so a log axis had one bin fewer than it
	# asked for, and "xbins => 1" gave one edge, no bins at all, and died in
	# np.max as "zero-size array". The test is on the axes, not on "logscale"
	# itself, which as an empty array was true and took this branch for none.
	if ( scalar keys %log_axis ) {
		foreach my $axis ( 'x', 'y' ) {
			my $min   = $end{ $axis . 'min' };
			my $max   = $end{ $axis . 'max' };
			my $edges = $plot->{"${axis}bins"} + 1;
			if ( $log_axis{$axis} ) {
				say {$args->{fh}} "ax$ax.set_$axis" . 'scale("log")';
				say {$args->{fh}} "${axis}bins = np.logspace(np.log10($min), np.log10($max), $edges)";
			} else {
				say {$args->{fh}} "${axis}bins = np.linspace($min, $max, $edges)";
			}
		}
		$options = ", bins = [xbins, ybins] $options";
	} else {
		$options = ", ($plot->{xbins}, $plot->{ybins}) $options";
	}
	say {$args->{fh}}	"hist2d_n, hist2d_xedges, hist2d_yedges, im$ax = ax$ax.hist2d(x, y $options $range)";
	say {$args->{fh}} 'max_hist2d_box = np.max(hist2d_n)';
	say {$args->{fh}} 'min_hist2d_box = np.min(hist2d_n)';
	say {$args->{fh}} "print(f'plot $ax hist2d density range = [{min_hist2d_box}, {max_hist2d_box}]')";
	return 0 if $plot->{show_colorbar} == 0;
	my $opts = colorbar_args($plot);    # cblabel is written below
#	say { $args->{fh} } "cbar = fig.colorbar(im$ax $opts)" if $plot->{colorbar_on};
	# As in hexbin_helper: "colorbar_on" used to be read only for the shared
	# colorbar, so "colorbar_on => 0" drew one anyway and the documentation
	# had to tell the reader to use "show_colorbar" instead. Both now work, and
	# a subplot whose colorbar plt() turns off for sharing stays off.
	if ( $plot->{colorbar_on} ) {
		if ( defined $plot->{cblabel} ) {
		  say { $args->{fh} } "plt.colorbar(im$ax, label = " . py_str($plot->{cblabel}) . " $opts)";
		} else {
		  say { $args->{fh} } "plt.colorbar(im$ax, label = 'Density' $opts)";
		}
	}
}

sub imshow_helper {
	my ($args) = @_;
	my $current_sub = ( split( /::/, ( caller(0) )[3] ) )[-1]
	; # https://stackoverflow.com/questions/2559792/how-can-i-get-the-name-of-the-current-subroutine-in-perl
	if ( ref $args ne 'HASH' ) {
	  die
	"args must be given as a hash ref, e.g. \"$current_sub({ data => \@blah })\"";
	}
	my @reqd_args = (
	  'ax',
	  'fh',      # e.g. $py, $fh, which will be passed by the subroutine
	  'plot',    # args to original function
	);
	my @undef_args = grep { !defined $args->{$_} } @reqd_args;
	if ( scalar @undef_args > 0 ) {
	  p @undef_args;
	  die 'the above args are necessary, but were not defined.';
	}
	my @opt = (@ax_methods, @plt_methods, @fig_methods, @arg, 'ax', @{ $opt{$current_sub} });
	my $plot = $args->{plot};
	@undef_args = grep {
	  my $key = $_;
	  not grep { $_ eq $key } @opt
	} keys %{$plot};
	if ( scalar @undef_args > 0 ) {
		bad_keyword_error({
			bad       => \@undef_args,
			accepted  => \@opt,
			preferred => $opt{$current_sub},
			type      => $plot->{plot_type},
			sub       => $current_sub
		});
	}
	cb_limits( $plot, $current_sub );
	my $data_ref = ref $plot->{data};
	if ($data_ref ne 'ARRAY') {
		p $args;
		die "$current_sub can only accept 2-D arrays as input in \"data\", but received $data_ref";
	}
	# An empty image is refused here, by name: it has nothing to draw, and it
	# used to reach Python as "vmin = inf", a NameError about nothing in the
	# data.
	my @bad_rows = grep { ref $plot->{data}[$_] ne 'ARRAY' } 0 .. $#{ $plot->{data} };
	if (scalar @bad_rows > 0) {
		p @bad_rows;
		die "the above rows of \"data\" are not array references, which $current_sub needs";
	}
	if ((scalar @{ $plot->{data} } == 0) || (scalar grep { scalar @{$_} > 0 } @{ $plot->{data} }) == 0) {
		die "$current_sub was given no data to draw";
	}
	# Every row the same length: numpy refused a ragged image from inside
	# matplotlib, as "setting an array element with a sequence ... inhomogeneous
	# shape", which named no row.
	my %row_lengths;
	$row_lengths{ scalar @{$_} } = 1 foreach @{ $plot->{data} };
	if ( scalar keys %row_lengths > 1 ) {
		die "the rows of \"data\" have different lengths ("
		 . join( ', ', map { scalar @{ $plot->{data}[$_] } } 0 .. $#{ $plot->{data} } )
		 . "), but $current_sub draws a rectangle of cells";
	}
	# An undefined cell, refused by name. It was counted as a string, and
	# without a "stringmap" the image died as needing "a map to translate
	# strings to integers", for numeric data that held no strings.
	my @undef_cells;
	foreach my $r ( 0 .. $#{ $plot->{data} } ) {
		push @undef_cells, map { "[$r][$_]" } grep { not defined $plot->{data}[$r][$_] } 0 .. $#{ $plot->{data}[$r] };
	}
	if ( scalar @undef_cells > 0 ) {
		splice @undef_cells, 5, scalar(@undef_cells) - 5, '...' if scalar @undef_cells > 5;    # enough to find them by
		die "$current_sub cannot draw an undefined cell, and \"data\" has them at " . join( ', ', @undef_cells ) . '; a NaN is drawn as an empty cell';
	}
	my $non_numeric_data = 0;
	foreach my $row (@{ $plot->{data} }) {
		if (grep {not looks_like_number($_)} @{ $row }) {
			$non_numeric_data = 1;
			last;
		}
	}
	$plot->{cb_logscale} = bool_option( $plot->{cb_logscale}, 'cb_logscale', $current_sub );
	if (($non_numeric_data) && (not defined $plot->{stringmap})) {
		p $args;
		die "$current_sub needs a map to translate strings to integers";
	}
	# Each key of stringmap gets an integer, in sorted order. The integers come
	# from a range, not from "scalar @ytick_labels" as they were: perl returns
	# the count of an empty array as a shared 0 that also carries the string
	# "0", the first category's 0 was copied from it, and JSON::XS -- which
	# JSON::MaybeXS uses when it has no Cpanel::JSON::XS -- wrote it as "0".
	# One string among the integers made numpy read the whole image as text,
	# and imshow died as "Image data of dtype <U21 cannot be converted to
	# float".
	my @strings = sort keys %{ $plot->{stringmap} };
	my %intmap = map { $strings[$_] => $_ } 0 .. $#strings;
	my @ytick_labels = @{ $plot->{stringmap} }{@strings};
	# The rows drawn: the caller's own, or for string data a translated copy.
	# The strings used to be replaced in place, so the caller's array came back
	# holding integers; and a string that "stringmap" did not name became an
	# undefined cell, drawn blank with nothing said.
	my $data = $plot->{data};
	if ($non_numeric_data) {
		my %unmapped;
		foreach my $row (@{ $data }) {
			$unmapped{ $_ // 'undef' }++ foreach grep { ( not defined $_ ) || ( not defined $intmap{$_} ) } @{ $row };
		}
		if (scalar keys %unmapped > 0) {
			my @unmapped = sort keys %unmapped;
			p @unmapped;
			die "the above values of \"data\" are not keys of \"stringmap\", which $current_sub needs to give each one a color";
		}
		$data = [ map { [ map { $intmap{$_} } @{ $_ } ] } @{ $data } ];
	} else {
		# Numbers as numbers. write_data sends "d" through JSON, which writes a
		# scalar last used as a string -- a row split from a line of a file -- as
		# a JSON string, and numpy refused such rows as "Image data of dtype <U1
		# cannot be converted to float". A copy, since the rows are the caller's.
		# JSON has no NaN or infinity, and the encoder writes both as null, which
		# numpy refused as "Image data of dtype object"; they travel as the
		# strings "nan", "inf" and "-inf" instead, which the float conversion
		# written after the data below reads back as the numbers they were.
		$data = [ map { [ map { nonfinite_name($_) // 0 + $_ } @{ $_ } ] } @{ $data } ];
	}
	my ( $min_val, $max_val );    # the ends of a stringmap's scale; numbers are left to norm_args
	my $opts = '';
	if ($non_numeric_data) {
		my @prop_cycle = ('#1f77b4', '#ff7f0e', '#2ca02c', '#d62728', '#9467bd', '#8c564b', '#e377c2',
 '#7f7f7f', '#bcbd22', '#17becf'); #plt.rcParams['axes.prop_cycle']
		my $n_strings = scalar keys %intmap;
		if ( $n_strings > scalar @prop_cycle ) {
			# More categories than the default property cycle has colors. The
			# slice used to run off the end of @prop_cycle and die inside
			# join() as "Use of uninitialized value", naming neither
			# "stringmap" nor the number of categories, so an 11th category
			# was an unexplained crash. A continuous colormap resampled to the
			# number of categories gives that many distinct colors for any
			# number of them.
			say { $args->{fh} } 'import matplotlib';
			say { $args->{fh} } "this_cmap = matplotlib.colormaps['gist_rainbow'].resampled($n_strings)";
		} else {
			say { $args->{fh} } 'from matplotlib.colors import ListedColormap';
			say { $args->{fh} } 'colors = [' . py_list( @prop_cycle[ 0 .. $n_strings - 1 ] ) . ']';
			say { $args->{fh} } 'this_cmap = ListedColormap(colors)';
		}
		warn "deleting \"$plot->{cmap}\" because string data is present" if defined $plot->{cmap};
		delete $plot->{cmap};
		$min_val = 0;
		$max_val = max(values %intmap);
		$opts .= ', cmap = this_cmap';
	}
	write_data({
		data => $data,
		fh   => $args->{fh},
		name => 'd',
	});
	# Only where a value needs it, so that an image of whole numbers is still
	# drawn from whole numbers.
	if ( ( not $non_numeric_data ) && ( grep { grep { m/^-?(?:nan|inf)$/ } @{$_} } @{$data} ) ) {
		say { $args->{fh} } 'import numpy as np';
		say { $args->{fh} } 'd = np.asarray(d, dtype = float)';
	}
	my $ax = $args->{ax} // '';
	foreach my $opt (grep {defined $plot->{$_}} ('cmap')) { # strings
		$opts .= ", $opt = " . py_str( $plot->{$opt} );
	}
	# Categories have no scale to put on a log axis.
	if ( $non_numeric_data && $plot->{cb_logscale} ) {
		die "\"cb_logscale\" means nothing for $current_sub with a \"stringmap\": its colors are categories, not a scale";
	}
	# vmin and vmax were written as given, so a word was a bare Python name,
	# and "cb_logscale" was accepted and never read. An image with no finite
	# value leaves the ends to matplotlib; they came out as "vmin = inf".
	foreach my $v ( grep { defined $plot->{$_} } ( 'vmin', 'vmax' ) ) {
		check_numbers( [ $plot->{$v} ], "\"$v\"", $current_sub );
	}
	$opts .= norm_args({
		lo     => $plot->{vmin} // ( $non_numeric_data ? $min_val : undef ),
		hi     => $plot->{vmax} // ( $non_numeric_data ? $max_val : undef ),
		values => $non_numeric_data ? [] : [ map { @{$_} } @{$data} ],
		log    => $plot->{cb_logscale},
		fh     => $args->{fh},
		sub    => $current_sub
	});
	say { $args->{fh} } "im$ax = ax$ax.imshow(d, aspect = 'auto' $opts)";
	$opts = '';
	if ($non_numeric_data) {
		# One tick per category, at the middle of its band of the colorbar.
		# The colormap has one color per category and spans [0, $max_val], so
		# category i covers [i/n, (i+1)/n] of that span and its middle sits at
		# $max_val * (2i+1) / 2n. The formula here was "$_ + 0.5 - $_/$max_val",
		# which divided by zero when there was a single category and put both
		# ticks in the same place when there were two.
		my $n_strings = $max_val + 1;
		$opts .= ', ticks = ['
		 . join( ',', map { $max_val * ( 2 * $_ + 1 ) / ( 2 * $n_strings ) } 0 .. $max_val ) . ']';
	}
	# py_str, not "'$value'": a cblabel is prose, and "Farmer's yield" closed
	# the literal early and left the script unparseable.
	$opts .= ', label = ' . py_str( $plot->{cblabel} ) if defined $plot->{cblabel};
	$opts .= colorbar_args($plot);
	say { $args->{fh} } "cbar = fig.colorbar(im$ax $opts)" if $plot->{colorbar_on};
	if (($non_numeric_data) && ($plot->{colorbar_on})) {
		# The colorbar's own set_ticklabels, which labels whichever axis its
		# ticks are on. cbar.ax.set_yticklabels was written whatever the
		# orientation, and a horizontal colorbar, whose ticks are on x, died as
		# "The number of FixedLocator locations (0) ... does not match the number
		# of labels".
		say { $args->{fh} } 'cbar.set_ticklabels([' . py_list(@ytick_labels) . '])';
	}
}

sub pie_helper {
	my ($args) = @_;
	my $current_sub = ( split( /::/, ( caller(0) )[3] ) )[-1]
	; # https://stackoverflow.com/questions/2559792/how-can-i-get-the-name-of-the-current-subroutine-in-perl
	if ( ref $args ne 'HASH' ) {
	  die
	"args must be given as a hash ref, e.g. \"$current_sub({ data => \@blah })\"";
	}
	my @reqd_args = (
	  'ax',
	  'fh',   # e.g. $py, $fh, which will be passed by the subroutine
	  'plot', # args to original function
	);
	my @undef_args = grep { !defined $args->{$_} } @reqd_args;
	if ( scalar @undef_args > 0 ) {
	  p @undef_args;
	  die 'the above args are necessary, but were not defined.';
	}
	my @opt = (@ax_methods, @plt_methods, @fig_methods, @arg, 'ax', @{ $opt{$current_sub} });
	my $plot      = $args->{plot};
	my @undef_opt = grep {
	  my $key = $_;
	  not grep { $_ eq $key } @opt
	} keys %{$plot};
	if ( scalar @undef_opt > 0 ) {
		bad_keyword_error({
			bad       => \@undef_opt,
			accepted  => \@opt,
			preferred => $opt{$current_sub},
			type      => $plot->{plot_type},
			sub       => $current_sub
		});
	}
	my @key_order;
	if ( defined $plot->{key_order} ) {
	  @key_order = check_key_order({
	  	keys   => $plot->{key_order},
	  	data   => $plot->{data},
	  	option => 'key_order',
	  	sub    => $current_sub
	  });
	} else {
	  @key_order = sort keys %{ $plot->{data} };
	}
	# As in barplot_helper: a wedge size is written into the script as it
	# stands, so a non-numeric one becomes a bare Python name and the script
	# dies as a NameError with nothing to say about the data.
	foreach my $key (@key_order) {
		if ( not looks_like_number( $plot->{data}{$key} ) ) {
			p $plot->{data};
			die "\"$key\" is not a number, which $current_sub needs to size a wedge";
		}
		# matplotlib refuses these as "Wedge sizes must be finite numbers"
		die "\"$key\" is not a finite number, which $current_sub needs to size a wedge" unless is_finite( $plot->{data}{$key} );
		# and these as "Wedge sizes 'x' must be non negative values"
		die "\"$key\" is $plot->{data}{$key}, but $current_sub cannot size a wedge below 0" if $plot->{data}{$key} < 0;
	}
	# and nothing at all, which matplotlib divides by: "x must have a positive sum"
	if ( not grep { $plot->{data}{$_} > 0 } @key_order ) {
		die "every wedge of $current_sub is 0, so there is no pie to divide between them";
	}
	$plot->{autopct} = $plot->{autopct} // '';
	my $opt = '';
	if ( $plot->{autopct} ne '' ) {
	$opt .= ", autopct = " . py_str( $plot->{autopct} );
	}
	foreach my $arg ( grep { defined $plot->{$_} } 'labeldistance', 'pctdistance' ) {
	  check_numbers( [ $plot->{$arg} ], "\"$arg\"", $current_sub );    # written bare, so a word was a NameError
	  $opt .= ", $arg = " . py_num( $plot->{$arg} );
	}
	write_data({
		data => \@key_order,
		fh   => $args->{fh},
		name => 'labels',
	});
	say { $args->{fh} } 'vals = ['
	. py_nums( @{ $plot->{data} }{@key_order} ) . ']';
	my $ax = $args->{ax} // '';
	say { $args->{fh} } "ax$ax.pie(vals, labels = labels $opt)";
}

sub plot_helper {
	my ($args) = @_;
	my $current_sub = ( split( /::/, ( caller(0) )[3] ) )[-1]
	; # https://stackoverflow.com/questions/2559792/how-can-i-get-the-name-of-the-current-subroutine-in-perl
	if ( ref $args ne 'HASH' ) {
		die "args must be given as a hash ref, e.g. \"$current_sub({ data => \@blah })\"";
	}
	my @reqd_args = (
		'ax',	'fh',# e.g. $py, $fh, which will be passed by the subroutine
		'plot',    # args to original function
	);
	my @undef_args = grep { !defined $args->{$_} } @reqd_args;
	if ( scalar @undef_args > 0 ) {
	  p @undef_args;
	  die 'the above args are necessary, but were not defined.';
	}
	my @opt = (@ax_methods, @fig_methods, @arg, @plt_methods, 'ax', @{ $opt{$current_sub} });
	my $plot = $args->{plot};
	my @bad_opt = grep {
	  my $key = $_;
	  not grep { $_ eq $key } @opt
	} keys %{$plot};
	if ( scalar @bad_opt > 0 ) {
		bad_keyword_error({
			bad       => \@bad_opt,
			accepted  => \@opt,
			preferred => $opt{$current_sub},
			type      => $plot->{plot_type},
			sub       => $current_sub
		});
	}
	$plot->{show_legend} = bool_option( $plot->{show_legend} // 1, 'show_legend', $current_sub );
	foreach my $axis ( logscale_axes( $plot->{logscale}, $current_sub ) ) { # x, y
		say {$args->{fh}} "ax$args->{ax}.set_$axis" . 'scale("log")';
	}
	my @twinx;
	# The one twin of these axes, made the first time a line asks for it and
	# shared by every twinned line after, including those of an "add" graph on
	# the same axes. Each twinned line used to get a twin of its own, so two of
	# them had two right-hand axes, each with its own limits, their ticks drawn
	# over one another on the same spine.
	my $twin = sub {
		my $ax = "ax$args->{ax}";
		if ( not defined $twin_axes{$ax} ) {
			$twin_axes{$ax} = "twinx_$ax";
			say { $args->{fh} } "$twin_axes{$ax} = $ax.twinx() # " . __LINE__;
		}
		return $twin_axes{$ax};
	};
	# Allow a single line entered as two bare array refs, with no enclosing
	# pair-array and no hash key:
	#     data => [ \@x, \@y ]
	# Promote it to the canonical array-of-pairs form so the array path below
	# handles it unchanged:
	#     data => [ [ \@x, \@y ] ]
	# The discriminator vs. the multi-line form (data => [ [\@x,\@y], ... ]) is
	# data->[0][0]: a number here, an ARRAY ref in the multi-line form.
	if (   ( ref $plot->{data} eq 'ARRAY' )
		&& ( scalar @{ $plot->{data} } == 2 )
		&& ( ref $plot->{data}[0] eq 'ARRAY' )
		&& ( ref $plot->{data}[1] eq 'ARRAY' )
		&& ( ref $plot->{data}[0][0] ne 'ARRAY' ) )
	{
		$plot->{data} = [ $plot->{data} ];
	}
	if (ref $plot->{data} eq 'ARRAY') {
		if (defined $plot->{set_options}) {
			my $ref_type = ref $plot->{set_options};
			# a scalar applies to every line (handy for the single-line form);
			# an array gives one option string per line (positional)
			if ($ref_type eq 'ARRAY') {
				my $n_set_opt = scalar @{ $plot->{set_options} };
				my $n_data = scalar @{ $plot->{data} };
				if ($n_set_opt > $n_data) {
					p $args;
					die "there are $n_set_opt sets for options, but only $n_data data points.";
				}
			} elsif ($ref_type ne '') {
				p $args;
				die "\"set_options\" must be a scalar (applied to every line) or an array (one per line) when data is an array, but \"$ref_type\" was given.";
			}
		}
		if (defined $plot->{twinx}) {
			my $twinx_ref = ref $plot->{twinx};
			if ($twinx_ref eq '') {
				die "twinx must be an array index, not \"$plot->{twinx}\"" unless $plot->{twinx} =~ m/^\d+$/;
				@twinx = $plot->{twinx};
			} elsif ($twinx_ref eq 'ARRAY') {
				@bad_opt = grep {$_ !~ m/^\d+$/} @{ $plot->{twinx} };
				if (scalar @bad_opt > 0) {
					p @bad_opt;
					die 'data that could not possibly be an array index for twinx is shown above';
				}
				@twinx = @{ $plot->{twinx} };
			} else {
				# Any other reference fell off the end of this chain and was
				# ignored without a word, so a twinx given in the hash form
				# ("twinx => { B => 1 }") against array data simply did not
				# draw a second axis.
				die "$current_sub: \"data\" is an array, so \"twinx\" is an index or an array of indices into it, not a $twinx_ref reference";
			}
		}
		if (defined $plot->{twinx_args}) {
			my $ref = ref $plot->{twinx_args};
			die "\"twinx_args\" must be a hash, but $ref was entered" unless $ref eq 'HASH';
			check_twinx_args( $plot->{twinx_args}, $current_sub );
			@bad_opt = grep {$_ !~ m/^\d+$/} keys %{ $plot->{twinx_args} };
			if (scalar @bad_opt > 0) {
				p @bad_opt;
				die 'the above keys are not hash indices';
			}
			foreach my $idx (keys %{ $plot->{twinx_args} }) {
				next if grep {$idx == $_} @twinx;
				push @twinx, $idx;
			}
		}
		# An index past the last line was ignored without a word, where the
		# hash form refuses a key that is not in "data".
		my $n_lines = scalar @{ $plot->{data} };
		my @past_end = sort { $a <=> $b } grep { $_ >= $n_lines } @twinx;
		if ( scalar @past_end > 0 ) {
			die "$current_sub: \"twinx\" or \"twinx_args\" names line " . join( ', ', @past_end ) . ", but \"data\" has $n_lines line" . ( $n_lines == 1 ? '' : 's' ) . ', indexed from 0';
		}
		my $arr_i = 0;
		foreach my $arr (@{ $plot->{data} }) {
			my $ref = ref $arr;
			if ($ref ne 'ARRAY') {
				p $plot->{data}[$arr_i];
				die "index $arr_i is \"$ref\" but must be \"ARRAY\"";
			}
			my $n_elem = scalar @{ $arr };
			if ($n_elem != 2) {
				p $arr;
				die "there must be 2 array references (x, y) but index $arr_i has $n_elem";
			}
			@bad_opt = map { scalar @{ $arr->[$_] } } (0,1);
			if ($bad_opt[0] != $bad_opt[1]) {
				say STDERR "index $arr_i must have arrays/array refs of equal length, but these lengths were given:";
				p @bad_opt;
				die 'the array/array ref lengths must be equal';
			}
			foreach my $i (0,1) {
				my $max_i = scalar @{ $arr->[$i] } - 1;
				@bad_opt = grep {not looks_like_number($arr->[$i][$_])} 0..$max_i;
				next if scalar @bad_opt == 0; # it's fine, don't worry
				p $plot->{data}[$arr_i];
				p @bad_opt;
				@bad_opt = @{ $arr->[$i] }[@bad_opt];
				say STDERR 'have these non-numeric values:';
				p @bad_opt;
				die "Array index $arr_i/axis $i has non-numeric values (above)";
			}
			my $options = '';
			say { $args->{fh} } 'x = [' . py_nums( @{ $arr->[0] } ) . ']';
			say { $args->{fh} } 'y = [' . py_nums( @{ $arr->[1] } ) . ']';
			if ( defined $plot->{set_options} ) {
				my $so_ref = ref $plot->{set_options};
				if ( $so_ref eq '' ) {    # scalar: same options for every line
					$options = ", $plot->{set_options}";
				} elsif (   ( $so_ref eq 'ARRAY' )
						&& ( defined $plot->{set_options}[$arr_i] ) ) {
					$options = ", $plot->{set_options}[$arr_i]";    # one per line
				}
			}
			my $ax = "ax$args->{ax}";
			if (grep {$arr_i == $_} @twinx) {
				my $twin_ax = $twin->();
				say { $args->{fh} } "$twin_ax.plot(x, y $options) # " . __LINE__;
				if (defined $plot->{twinx_args}{$arr_i}) {
					plot_args({
						fh        => $args->{fh},
						args      => $plot->{twinx_args}{$arr_i},
						ax        => $twin_ax,
						no_legend => 1    # its lines go in the legend of $ax
					});
				}
			} else {
				say { $args->{fh} } "ax$args->{ax}.plot(x, y $options) # " . __LINE__;
			}
			$arr_i++;
		}
		return 1; # the rest only applies if $plot->{data} is a hash
	}
	my @key_order;
	if ( defined $plot->{key_order} ) {
		@key_order = check_key_order({
			keys   => $plot->{key_order},
			data   => $plot->{data},
			option => 'key_order',
			sub    => $current_sub
		});
	} else {
		@key_order = sort keys %{ $plot->{data} };
	}
	if ((defined $plot->{set_options}) && (ref $plot->{set_options} eq 'HASH')) {
		@bad_opt = sort grep {!defined $plot->{data}{$_}} keys %{ $plot->{set_options} };
		if (scalar @bad_opt > 0) {
			p @bad_opt;
			die "the above options are defined for undefined data sets in $current_sub.";
		}
	}
	if (defined $plot->{twinx}) {
		my $twinx_ref = ref $plot->{twinx};
		if ($twinx_ref eq '') {
			die "twinx \"$plot->{twinx}\" is not a key in data" unless defined $plot->{data}{ $plot->{twinx} };
			@twinx = ($plot->{twinx});
		} elsif ($twinx_ref eq 'HASH') {
			@bad_opt = sort grep {!defined $plot->{data}{$_}} keys %{ $plot->{twinx} };
			if (scalar @bad_opt > 0) {
				p @bad_opt;
				die 'data for undefined data keys is shown above';
			}
			@twinx = sort keys %{ $plot->{twinx} };
		} else {
			# As in the array branch above: anything else was ignored in
			# silence, so "twinx => ['B']" against a hash of sets drew nothing
			# and said nothing.
			die "$current_sub: \"data\" is a hash, so \"twinx\" is a data key or a hash of them, not a $twinx_ref reference";
		}
	}
	if (defined $plot->{twinx_args}) {
		my $ref = ref $plot->{twinx_args};
		die "\"twinx_args\" must be a hash, but $ref was entered" unless $ref eq 'HASH';
		check_twinx_args( $plot->{twinx_args}, $current_sub );
		@bad_opt = sort grep {!defined $plot->{data}{$_}} keys %{ $plot->{twinx_args} };
		if (scalar @bad_opt > 0) {
			p @bad_opt;
			die 'the above keys are not present in data keys';
		}
		foreach my $set (keys %{ $plot->{twinx_args} }) {
			next if grep {$set eq $_} @twinx;
			push @twinx, $set;
		}
	}
	foreach my $set (@key_order) {
		my $set_ref = ref $plot->{data}{$set};
		if ( $set_ref ne 'ARRAY' ) {
			p $plot->{data}{$set};
			die "$set must have two arrays, x and y coordinates, or one array of y values, but instead has a $set_ref";
		}
		# A set of plain values, with no array among them, is y alone, and is
		# drawn against 0 .. n-1. The pair is built here rather than written
		# back, so the caller's data is left as it was given.
		my $xy = $plot->{data}{$set};
		my $n_refs = grep { ref } @{$xy};
		if ( ( $n_refs == 0 ) && ( scalar @{$xy} > 0 ) ) {
			$xy = [ [ 0 .. $#{$xy} ], $xy ];
		} elsif ( $n_refs < scalar @{$xy} ) {
			p $xy;
			die "$current_sub: set \"$set\" mixes arrays with plain values: it must be [ \\\@x, \\\@y ] or one array of y values";
		}
		my $n_arrays = scalar @{ $xy };
		if ( $n_arrays != 2 ) {
			p $xy;
			die "$n_arrays were entered for $set, but there must be exactly 2";
		}
		my @n_elem = map { scalar @{ $xy->[$_] }} (0,1);
		if ( $n_elem[0] != $n_elem[1] ) {
			p $xy;
			p @n_elem;
			die "$set has length = $n_elem[0] for x; length = $n_elem[1] for y: x & y must be of equal length";
		}
		foreach my $ax (0,1) {
			my $n = scalar @{ $xy->[$ax] };
			my @undef_i = grep {not defined $xy->[$ax][$_]} 0..$n-1;
			if (scalar @undef_i > 0) {
				p $plot;
				p @undef_i;
				my $max_i = scalar @{ $xy->[$ax] };
				die "set $set axis $ax has undefined indices, of max index $max_i in $current_sub";
			}
			# The array form of "data" has always refused these; the hash form
			# wrote them into the script, where 'a' became "y = [a,3]" and died
			# as a NameError.
			my @non_numeric = grep { not looks_like_number( $xy->[$ax][$_] ) } 0 .. $n - 1;
			if ( scalar @non_numeric > 0 ) {
				my @values = @{ $xy->[$ax] }[@non_numeric];
				p @values;
				die "set \"$set\" axis $ax has the above non-numeric values, which $current_sub cannot plot";
			}
		}
		my $options = '';
		say { $args->{fh} } 'x = [' . py_nums( @{ $xy->[0] } ) . ']';
		say { $args->{fh} } 'y = [' . py_nums( @{ $xy->[1] } ) . ']';
		if (   ( defined $plot->{set_options} )
			&& ( ref $plot->{set_options} eq '' ) )
		{
			$options = ", $plot->{set_options}";
		}
		if ( ( ref $plot->{set_options} eq 'HASH' ) && ( defined $plot->{set_options}{$set} ) ) {
			$options = ", $plot->{set_options}{$set}";
		}
		my $label = '';
		if ( $plot->{show_legend} ) {
			$label = ',label = ' . py_str($set);
		}
		my $ax = "ax$args->{ax}";
		if (grep {$set eq $_} @twinx) { # this set has
			my $twin_ax = $twin->();
			say { $args->{fh} } "$twin_ax.plot(x, y $label $options) # " . __LINE__;
			if (defined $plot->{twinx_args}{$set}) {
				plot_args({
					fh        => $args->{fh},
					args      => $plot->{twinx_args}{$set},
					ax        => $twin_ax,
					no_legend => 1    # its lines go in the legend of $ax
				});
			}
		} else {
			say { $args->{fh} } "ax$args->{ax}.plot(x, y $label $options) # " . __LINE__;
		}
	}
	return 1;
}

sub check_twinx_args {
	# Die naming any keyword of a "twinx_args" hash that no axes, figure or
	# pyplot method answers to. plot_args checks its own arguments, not the
	# hash it is handed to write out, so a typo such as "ylable" was dropped
	# without a word.
	my ( $twinx_args, $current_sub ) = @_;
	my @accepted = ( @ax_methods, @fig_methods, @plt_methods );
	my %accepted = map { $_ => 1 } @accepted;
	foreach my $set ( sort keys %{$twinx_args} ) {
		my $ref = ref $twinx_args->{$set};
		if ( $ref ne 'HASH' ) {
			die "\"twinx_args\" for \"$set\" must be a hash of axes options, but " . ( $ref ? "a $ref reference" : 'a scalar' ) . ' was entered';
		}
		my @bad = grep { not $accepted{$_} } keys %{ $twinx_args->{$set} };
		next if scalar @bad == 0;
		bad_keyword_error({
			bad      => \@bad,
			accepted => \@accepted,
			sub      => "$current_sub \"twinx_args\" for \"$set\""
		});
	}
}
sub check_scatter_values {
	# Die unless every value of one scatter axis is a defined number.
	#
	# Only undefined values were refused before, and only for x and y: a
	# string in any axis, or anything at all in the color axis, was written
	# into the script as it stands and died there as a python NameError.
	my ( $values, $what, $current_sub ) = @_;
	if ( ref $values ne 'ARRAY' ) {
		my $got = ref $values ? ( ref $values ) . ' reference' : 'a scalar';
		die "$current_sub: $what must be an array of numbers, not $got";
	}
	my @bad = grep { not looks_like_number( $values->[$_] ) } 0 .. $#{$values};
	return if scalar @bad == 0;
	p @bad;
	die "$what is undefined or not a number at the above indices in $current_sub";
}
sub check_scatter_lengths {
	# Die unless the axes of one scatter set -- x, y and the color key, if any
	# -- hold the same number of values, as the documentation requires.
	# matplotlib refused a mismatch as "x and y must be the same size", which
	# named neither the keys nor the set. An axis that is not an array is left
	# for check_scatter_values to refuse.
	my ( $set, $keys, $where, $current_sub ) = @_;
	my @arrays = grep { ref $set->{$_} eq 'ARRAY' } @{$keys};
	my %lengths = map { scalar @{ $set->{$_} } => 1 } @arrays;
	return if scalar keys %lengths <= 1;
	die "$current_sub: the axes$where must all have the same number of values, but "
	 . join( ', ', map { "\"$_\" has " . scalar @{ $set->{$_} } } @arrays );
}
sub scatter_helper {
	my ($args) = @_;
	my $current_sub = ( split( /::/, ( caller(0) )[3] ) )[-1]
	; # https://stackoverflow.com/questions/2559792/how-can-i-get-the-name-of-the-current-subroutine-in-perl
	if ( ref $args ne 'HASH' ) {
		die "args must be given as a hash ref, e.g. \"$current_sub({ data => \@blah })\"";
	}
	my @reqd_args = (
	  'ax',  'fh', # e.g. $py, $fh, which will be passed by the subroutine
	  'plot',      # args to original function
	);
	my @undef_args = grep { !defined $args->{$_} } @reqd_args;
	if ( scalar @undef_args > 0 ) {
	  p @undef_args;
	  die 'the above args are necessary, but were not defined.';
	}
	my @opt = (@ax_methods, @plt_methods, @fig_methods, @arg, 'ax', @{ $opt{$current_sub} });
	my $plot      = $args->{plot};
	@undef_args = grep {
	  my $key = $_;
	  not grep { $_ eq $key } @opt
	} keys %{$plot};
	if ( scalar @undef_args > 0 ) {
		bad_keyword_error({
			bad       => \@undef_args,
			accepted  => \@opt,
			preferred => $opt{$current_sub},
			type      => $plot->{plot_type},
			sub       => $current_sub
		});
	}
	foreach my $cb ( grep { defined $plot->{$_} } ( 'cb_min', 'cb_max' ) ) {
		check_numbers( [ $plot->{$cb} ], "\"$cb\"", $current_sub );
	}
	cb_limits( $plot, $current_sub );    # scatter has no vmin or vmax of its own, so cb_min and cb_max are its only way to set them
	my $overall_ref = ref $plot->{data};
	if ( $overall_ref ne 'HASH' ) {
		die
	"scatter only takes 1) hashes of arrays (single or 2) hash of hash of arrays; but $overall_ref was entered";
	}
	my ( %ref_counts, $plot_type );
	foreach my $set ( keys %{ $plot->{data} } ) {
		$ref_counts{ ref $plot->{data}{$set} }++;
	}
	my $ax = $args->{ax};
	if ( (scalar keys %ref_counts) > 1 ) {
		p $plot->{data};
		die "different kinds of data were entered to plot $ax; should be simple hash or hash of arrays.";
	}
	if ( defined $ref_counts{ARRAY} ) {
		$plot_type = 'single';
	} elsif ( defined $ref_counts{HASH} ) {
		$plot_type = 'multiple';
	} else {
		p $plot->{data};
		p %ref_counts;
		die 'Could not determine scatter type for the above data.';
	}
	$plot->{cmap} = $plot->{cmap} // 'gist_rainbow';
	$plot->{cb_logscale} = bool_option( $plot->{cb_logscale}, 'cb_logscale', $current_sub );
	foreach my $axis ( logscale_axes( $plot->{logscale}, $current_sub ) ) { # x, y 
		say {$args->{fh}} "ax$ax.set_$axis" . 'scale("log")';
	}
	# "set_options" is one string of options for a single set, and a hash of
	# one per set for several. A string given to several sets died as "Can't
	# use string as a HASH ref"; a hash given to a single set was ignored.
	if ( defined $plot->{set_options} ) {
		my $so_ref = ref $plot->{set_options};
		if ( ( $plot_type eq 'single' ) && ( $so_ref ne '' ) ) {
			die "$current_sub: \"data\" is a single set, so \"set_options\" is one string of options, e.g. 'marker = \"v\"', not a $so_ref reference";
		}
		if ( ( $plot_type eq 'multiple' ) && ( $so_ref ne 'HASH' ) ) {
			die "$current_sub: \"data\" is a hash of sets, so \"set_options\" is a hash of one string of options per set, e.g. { A => 'marker = \"v\"' }, not "
			 . ( $so_ref ? "a $so_ref reference" : 'a string' );
		}
	}
	# "key_order" is the order of the sets, which "keys" -- the order of the
	# axes within a set -- cannot say; a single set has only the one.
	if ( ( defined $plot->{key_order} ) && ( $plot_type eq 'single' ) ) {
		die "$current_sub: \"key_order\" orders the sets of a hash of sets; for the axes of a single set, use \"keys\"";
	}
	if ( $plot_type eq 'single' ) { # only a single set of data
		my $options = '';
		my ( $color_key, @keys );
		if ( defined $plot->{'keys'} ) {
			@keys = check_key_order({
				keys   => $plot->{'keys'},
				data   => $plot->{data},
				option => 'keys',
				sub    => $current_sub
			});
		} else {
			@keys = sort { lc $a cmp lc $b || $a cmp $b } keys %{ $plot->{data} };    # tie-broken, or "x" and "X" came in hash order
		}
		my $n_keys = scalar keys %{ $plot->{data} };
		if ( ( $n_keys != 2 ) && ( $n_keys != 3 ) ) {
			p $plot->{data};
			die "scatterplots can only take 2 or 3 keys as data, but $current_sub received $n_keys";
		}
		if ( defined $plot->{color_key} ) {
			$color_key = $plot->{color_key};
			@keys = grep {$_ ne $plot->{color_key}} @keys;
		} elsif ( scalar @keys == 3 ) {
			$color_key = pop @keys;
		} elsif ( $n_keys == 3 ) {
			# As for several sets: "keys" named x and y of three keys, so the one
			# it left out is the color. It was drawn without one.
			my %named = map { $_ => 1 } @keys;
			($color_key) = grep { not $named{$_} } sort { lc $a cmp lc $b || $a cmp $b } keys %{ $plot->{data} };
		}
		if ( scalar @keys != 2 ) {
			p @keys;
			die "$current_sub needs one key for x and one for y, but \"keys\" and \"color_key\" leave the " . scalar(@keys) . ' above';
		}
		foreach my $i (0,1) {
			check_scatter_values( $plot->{data}{ $keys[$i] }, "\"$keys[$i]\"", $current_sub );
		}
		check_scatter_lengths( $plot->{data}, [ @keys, ( defined $color_key ? $color_key : () ) ], '', $current_sub );
		say { $args->{fh} } 'x = [' . py_nums( @{ $plot->{data}{ $keys[0] } } ) . ']';
		say { $args->{fh} } 'y = [' . py_nums( @{ $plot->{data}{ $keys[1] } } ) . ']';
		if (   ( defined $plot->{set_options} )
			&& ( ref $plot->{set_options} eq '' ) )
		{
			$options = ", $plot->{set_options}";
		}
		if ( defined $color_key ) {
			if (not defined $plot->{data}{$color_key}) {
				die "\"$color_key\" isn't defined for this scatter";
			}
			check_scatter_values( $plot->{data}{$color_key}, "\"$color_key\"", $current_sub );
			say { $args->{fh} } 'z = [' . py_nums( @{ $plot->{data}{$color_key} } ) . ']';
			# cb_min, cb_max and cb_logscale, which were accepted here and not read.
			# Left out where set_options set a scale of their own, which matplotlib
			# would refuse beside this one.
			my $range = '';
			if ( ( ( defined $plot->{vmin} ) || ( defined $plot->{vmax} ) || $plot->{cb_logscale} ) && ( $options !~ m/\b(?:vmin|vmax|norm)\s*=/ ) ) {
				$range = norm_args({
					lo     => $plot->{vmin},
					hi     => $plot->{vmax},
					values => $plot->{data}{$color_key},
					log    => $plot->{cb_logscale},
					fh     => $args->{fh},
					sub    => $current_sub
				});
			}
			say { $args->{fh} }
			  "im = ax$ax.scatter(x, y, c = z, cmap = " . py_str($plot->{cmap}) . "$range $options)";
			# The cb* options, "cblabel", "colorbar_on" and "shared_colorbar" were
			# all accepted here and none of them read: the colorbar was always drawn,
			# labelled with the color key, with only cbpad and cbdrawedges applied.
			my $cb_opts = colorbar_args($plot);
			if ( $plot->{colorbar_on} ) {
				say { $args->{fh} } "fig.colorbar(im, label = " . py_str( $plot->{cblabel} // $color_key ) . " $cb_opts)";
			}
		} else {
			say { $args->{fh} } "ax$ax.scatter(x, y $options)";
		}
		# quoted here because the key is data; see py_str above
		default_axis_labels( $plot, @keys );
	} elsif ( $plot_type eq 'multiple' ) { # multiple sets
		my @undefined_opts;
		foreach my $set ( sort keys %{ $plot->{set_options} } ) {
			next if grep { $set eq $_ } keys %{ $plot->{data} };
			push @undefined_opts, $set;
		}
		if ( scalar @undefined_opts > 0 ) {
			p $plot->{data};
			p $plot;
			say STDERR 'The data and options are above, but the following sets have options without data:';
			p @undefined_opts;
			die 'no data was defined for the above options';
		}
		# A set may be a single point, its values numbers rather than arrays:
		# catboost => { MAE => 0.41, R2 => 0.83 }. It is drawn as a scatter of
		# one point, labelled with the set's name. The wrapping goes into a copy
		# so that the caller's data is left as it was given.
		my %sets;
		foreach my $set ( keys %{ $plot->{data} } ) {
			my $inner = $plot->{data}{$set};
			if ( ( scalar keys %{$inner} > 0 ) && ( not grep { ref } values %{$inner} ) ) {
				$sets{$set} = { map { $_ => [ $inner->{$_} ] } keys %{$inner} };
			} else {
				$sets{$set} = $inner;
			}
		}
		# The order the sets are drawn in, which is the order of the legend and
		# of the markers handed out below. Sorted by name before, with no way to
		# change it, so the groups that "df" makes with "by" came out with 10
		# before 2, though the documentation promised numeric order.
		my @set_order;
		if ( defined $plot->{key_order} ) {
			@set_order = check_key_order({
				keys   => $plot->{key_order},
				data   => $plot->{data},
				option => 'key_order',
				sub    => $current_sub
			});
		} else {
			@set_order = sort keys %sets;
		}
		# Each set is labelled with its name, for the legend, unless this is
		# false. It was accepted and never read, so the legend was always drawn.
		$plot->{show_legend} = bool_option( $plot->{show_legend} // 1, 'show_legend', $current_sub );
		# Keys and color key of every set are settled, and every value checked,
		# before anything is written, because the color range is shared by all
		# sets and so has to be known before the first set is drawn.
		my ( %xy_keys, %color_key_of );
		foreach my $set ( sort keys %sets ) {
			my ( @keys, $color_key );
			if ( defined $plot->{'keys'} ) {
				 @keys = check_key_order({
				 	keys   => $plot->{'keys'},
				 	data   => $sets{$set},
				 	option => 'keys',
				 	sub    => "$current_sub set \"$set\""
				 });
			} else { # automatically take the key from the first; further sets should have the same labels
				 @keys = sort { lc $a cmp lc $b || $a cmp $b } keys %{ $sets{$set} };
			}
			my $n_keys = scalar keys %{ $sets{$set} };
			if ( ( $n_keys != 2 ) && ( $n_keys != 3 ) ) {
				p $plot->{data}{$set};
				die "scatterplots can only take 2 or 3 keys as data, but $current_sub received $n_keys";
			}
			foreach my $key (@keys) {
				check_scatter_values( $sets{$set}{$key}, "\"$key\" of set \"$set\"", $current_sub );
			}
			if ( defined $plot->{color_key} ) {
				$color_key = $plot->{color_key};
				@keys = grep {$_ ne $plot->{color_key}} @keys;
			} elsif ( scalar @keys == 3 ) {
				$color_key = pop @keys;
			} elsif ( $n_keys == 3 ) {
				# "keys" named x and y of three inner keys, so the one it left out
				# is the color, as the third is when the keys are sorted. This
				# popped the y key off "keys" instead, and died as "Use of
				# uninitialized value $keys[1] in hash element".
				my %named = map { $_ => 1 } @keys;
				($color_key) = grep { not $named{$_} } sort { lc $a cmp lc $b || $a cmp $b } keys %{ $sets{$set} };
			}
			if ( scalar @keys != 2 ) {
				p @keys;
				die "$current_sub set \"$set\" needs one key for x and one for y, but \"keys\" and \"color_key\" leave the " . scalar(@keys) . ' above';
			}
			if ( defined $color_key ) {
				if (not defined $sets{$set}{$color_key}) {
					die "\"$color_key\" isn't defined for set \"$set\"";
				}
				check_scatter_values( $sets{$set}{$color_key}, "\"$color_key\" of set \"$set\"", $current_sub );
				$color_key_of{$set} = $color_key;
			}
			check_scatter_lengths( $sets{$set}, [ @keys, ( defined $color_key ? $color_key : () ) ], " of set \"$set\"", $current_sub );
			$xy_keys{$set} = \@keys;
		}
		# One color scale for every set. Each ax.scatter normalises its own c to
		# its own minimum and maximum, so without this the same color meant a
		# different value in each set, the colorbar -- drawn from the last set --
		# was true only of that set, and a set of one point was always drawn in
		# the bottom color of the map whatever its value.
		my $color_range = '';
		if ( scalar keys %color_key_of > 0 ) {
			my @z = finite_values( map { @{ $sets{$_}{ $color_key_of{$_} } } } keys %color_key_of );
			# cb_min, cb_max and cb_logscale, where given, set the ends and the
			# kind of the shared scale; they were accepted and not read.
			$color_range = norm_args({
				lo     => $plot->{vmin},
				hi     => $plot->{vmax},
				values => \@z,
				log    => $plot->{cb_logscale},
				fh     => $args->{fh},
				sub    => $current_sub
			});
		}
		# The key the one colorbar is labelled with, from the last set that has
		# one. Kept apart from each set's own $color_key, which used to be this
		# same variable: a set with a third key left it defined for every set
		# after it, and a later set of only x and y died as '"z" isn't defined'.
		my $colorbar_key;
		# Sets colored by a third key are all drawn from the same colormap, so
		# color cannot tell them apart; each takes the next of these markers, in
		# the sorted order of the set names, unless its set_options name one. All
		# are filled, so each shows its color; the list repeats once it runs out. A
		# marker that set_options give to some set is left out, so that no other
		# set is given it too.
		my %taken = map { $_ => 1 } grep { defined }
			map { m/\bmarker\s*=\s*['"]([^'"]+)['"]/ ? $1 : undef } values %{ $plot->{set_options} // {} };
		my @markers = grep { not $taken{$_} } qw(o s ^ D v P X * < > p h d);
		@markers = ('o') if scalar @markers == 0; # all 13 taken: repeat the first
		my $marker_i = 0;
		foreach my $set (@set_order) {
			my $options = '';
			my @keys = @{ $xy_keys{$set} };
			my $color_key = $color_key_of{$set};
			if ( defined $plot->{set_options}{$set} ) {
				$options = ", $plot->{set_options}{$set}";
			}
			say { $args->{fh} } 'x = [' . py_nums( @{ $sets{$set}{ $keys[0] } } ) . ']';
			say { $args->{fh} } 'y = [' . py_nums( @{ $sets{$set}{ $keys[1] } } ) . ']';
			# The set's name as its label, unless it has a label of its own: the
			# uncolored path below added one regardless, and a "label" in
			# "set_options" made "keyword argument repeated", a SyntaxError.
			if ( ( $plot->{show_legend} ) && ( $options !~ m/\blabel\s*=/ ) ) {
				$options .= ', label = ' . py_str($set);
			}
			if ( defined $color_key ) {
				$colorbar_key = $color_key;
				say { $args->{fh} } 'z = [' . py_nums( @{ $sets{$set}{$color_key} } ) . ']';
				unless ( $options =~ m/\bmarker\s*=/ ) {
					$options .= ", marker = '$markers[ $marker_i % @markers ]'";
					$marker_i++;
				}
				# a set's own vmin, vmax or norm is its caller's decision, and
				# matplotlib refuses norm alongside vmin and vmax
				my $range = ( $options =~ m/\b(?:vmin|vmax|norm)\s*=/ ) ? '' : $color_range;
				say { $args->{fh} }
				"im = ax$ax.scatter(x, y, c = z, cmap = " . py_str($plot->{cmap}) . "$range $options)";
			} else {
				say { $args->{fh} }	"ax$ax.scatter(x, y$options)";
			}
			# quoted here because the key is data; see py_str above
			default_axis_labels( $plot, @keys );
	  }
	  if ( defined $colorbar_key ) {
		  my $cb_opts = colorbar_args($plot);
		  if ( $plot->{colorbar_on} ) {
			  say { $args->{fh} } 'plt.colorbar(im, label = ' . py_str( $plot->{cblabel} // $colorbar_key ) . "$cb_opts)";
		  }
	  }
	}
}

sub violin_helper {
	my ($args) = @_;
	my $current_sub = ( split( /::/, ( caller(0) )[3] ) )[-1]
	; # https://stackoverflow.com/questions/2559792/how-can-i-get-the-name-of-the-current-subroutine-in-perl
	if ( ref $args ne 'HASH' ) {
		die "args must be given as a hash ref, e.g. \"$current_sub({ data => \@blah })\"";
	}
	my @reqd_args = (
	  'fh',      # e.g. $py, $fh, which will be passed by the subroutine
	  'plot',    # args to original function
	);
	my @undef_args = grep { !defined $args->{$_} } @reqd_args;
	if ( scalar @undef_args > 0 ) {
	  p @undef_args;
	  die 'the above args are necessary, but were not defined.';
	}
	my @opt = (@ax_methods, @plt_methods, @fig_methods, @arg, 'ax', @{ $opt{$current_sub} });
	my $plot      = $args->{plot};
	my @undef_opt = grep {
	  my $key = $_;
	  not grep { $_ eq $key } @opt
	} keys %{$plot};
	if ( scalar @undef_opt > 0 ) {
		bad_keyword_error({
			bad       => \@undef_opt,
			accepted  => \@opt,
			preferred => $opt{$current_sub},
			type      => $plot->{plot_type},
			sub       => $current_sub
		});
	}
	$plot->{orientation} = $plot->{orientation} // 'vertical';
	if ( $plot->{orientation} !~ m/^(?:horizontal|vertical)$/ ) {
		die "$current_sub needs either \"horizontal\" or \"vertical\", not \"$plot->{orientation}\"";
	}
	if (ref $plot->{data} eq 'ARRAY') {
		my $tmp = delete $plot->{data};
		$plot->{data}{''} = $tmp;
	}
	my ( @xticks, @key_order );
	if ( defined $plot->{key_order} ) {
		@key_order = check_key_order({
			keys   => $plot->{key_order},
			data   => $plot->{data},
			option => 'key_order',
			sub    => $current_sub
		});
	} else {
		@key_order = sort keys %{ $plot->{data} };
	}
	my $ax = $args->{ax} // '';
	# Read as Python bools, as boxplot's switches are: "medians" was written as
	# given, so "medians => 'yes'" left "showmedians = yes" in the script, and
	# "whiskers" was tested for Perl truth, in which 'False' is true.
	$plot->{medians}  = bool_option( $plot->{medians}  // 1, 'medians',  $current_sub ) ? 'True' : 'False';    # by default, show median values
	$plot->{whiskers} = bool_option( $plot->{whiskers} // 1, 'whiskers', $current_sub );    # by default, make whiskers
	# As in boxplot_helper: a hash here was written as 'HASH(0x...)'.
	if ( ref $plot->{color} ) {
		die "\"color\" is one color for every violin in $current_sub, not a " . ref( $plot->{color} ) . ' reference; give one color per key in "colors", e.g. colors => { A => \'red\' }';
	}
	$plot->{edgecolor} = $plot->{edgecolor} // 'black';
	my $options = '';    # these args go to the plt.hist call
	say { $args->{fh} } 'd = []';
	# %values, rather than writing the filtered list back into $plot->{data}:
	# the arrays in there belong to the caller, and dropping the undefined and
	# non-numeric elements in place left the caller's own array shorter than
	# they wrote it.
	my %values;
	foreach my $key (@key_order) {
	  @{ $values{$key} } = grep { ( defined ) && looks_like_number($_) && ( not is_nan($_) ) } @{ $plot->{data}{$key} };
	  # A group left with nothing in it has no mean to draw, and the mean is
	  # computed by dividing by this count: it died as "Use of uninitialized
	  # value in division", which named neither the group nor the filtering
	  # that emptied it.
	  if ( scalar @{ $values{$key} } == 0 ) {
	  	my $n_given = scalar @{ $plot->{data}{$key} };
	  	die "\"$key\" has no numeric values for $current_sub to plot ($n_given value(s) given, all undefined, NaN or non-numeric)";
	  }
	  # An infinity gives the density estimate nothing to spread over and made
	  # the mean below "Inf", written into the script as a bare name.
	  my @infinite = grep { not is_finite($_) } @{ $values{$key} };
	  if ( scalar @infinite > 0 ) {
	  	p @infinite;
	  	die "\"$key\" has the above infinite values, which $current_sub cannot draw a density for";
	  }
	  say { $args->{fh} } 'd.append(['
		 . py_nums( @{ $values{$key} } ) . '])';
	}
	foreach my $axis ( logscale_axes( $plot->{logscale}, $current_sub ) ) { # x, y
		say {$args->{fh}} "ax$ax.set_$axis" . 'scale("log")';
	}
	# No "points": it is how many points the density curve is evaluated at,
	# not a count of data, and it used to be set to the size of the smallest
	# group, so a group of 5 values drew every violin as a 5-sided polygon.
	# matplotlib's default is 100.
	say { $args->{fh} } "vp = ax$ax.violinplot(d, showmeans=False, orientation = '$plot->{orientation}', showmedians = $plot->{medians})";
	if ( defined $plot->{colors} ) { # every hash key should have its own color defined
		# the below code helps to provide better error messages in case I make an error in calling the sub
		my @wrong_keys = grep { not defined $plot->{colors}{$_} } keys %{ $plot->{data} };
		if ( scalar @wrong_keys > 0 ) {
			p $plot;
			p @wrong_keys;
			die 'the above data keys have no defined color';
		}
		# list of pre-defined colors: https://matplotlib.org/stable/gallery/color/named_colors.html
		say { $args->{fh} } 'colors = ['
		 . py_list( @{ $plot->{colors} }{@key_order} ) . ']';

		# the above color list will have the same order, via the above hash slice
		say { $args->{fh} } 'for i, pc in enumerate(vp["bodies"], 1):';
		say { $args->{fh} } "\tpc.set_facecolor(colors[i-1])";
		say { $args->{fh} } "\tpc.set_edgecolor(" . py_str( $plot->{edgecolor} ) . ')';
	} else {
		say { $args->{fh} } 'for pc in vp["bodies"]:';
		if ( defined $plot->{color} ) {
			say { $args->{fh} } "\tpc.set_facecolor(" . py_str($plot->{color}) . ')';
		}
		say { $args->{fh} } "\tpc.set_edgecolor(" . py_str( $plot->{edgecolor} ) . ')';

		#		say {$args->{fh}} "\tpc.set_alpha(1)";
	}
	if ( $plot->{whiskers} ) {
		# https://matplotlib.org/stable/gallery/statistics/customized_violin.html
		say {$args->{fh} } 'import numpy as np';
		say {$args->{fh} } 'def adjacent_values(vals, q1, q3):';
		say {$args->{fh} } '	upper_adjacent_value = q3 + (q3 - q1) * 1.5';
		say {$args->{fh} }
		 '	upper_adjacent_value = np.clip(upper_adjacent_value, q3, vals[-1])';
		say {$args->{fh} } '	lower_adjacent_value = q1 - (q3 - q1) * 1.5';
		say {$args->{fh} }
		 '	lower_adjacent_value = np.clip(lower_adjacent_value, vals[0], q1)';
		say {$args->{fh} }
		 '	return lower_adjacent_value, upper_adjacent_value';
		say {$args->{fh} } 'np_data = np.array(d, dtype = object)';
		say {$args->{fh} } 'quartile1 = []';
		say {$args->{fh} } 'medians   = []';
		say {$args->{fh} } 'quartile3 = []';
		say {$args->{fh} } 'for subset in list(range(0, len(np_data))):';
		say {$args->{fh}} '	local_quartile1, local_medians, local_quartile3 = np.percentile(d[subset], [25, 50, 75])' . "\n";
		say {$args->{fh}} '	quartile1.append(local_quartile1)';
		say {$args->{fh}} '	medians.append(local_medians)';
		say {$args->{fh}} '	quartile3.append(local_quartile3)';
		# sorted(): adjacent_values reads the smallest and largest values as
		# vals[0] and vals[-1]. matplotlib's example sorts its data first; this
		# passed "d" in the caller's order, so for [10, 9, ..., 1, 100] the
		# lower whisker was clipped to q1 and not drawn at all.
		say {$args->{fh}} 'whiskers = np.array([';
		say {$args->{fh}} '    adjacent_values(sorted(subset), q1, q3)';
		say {$args->{fh}} '    for subset, q1, q3 in zip(d, quartile1, quartile3)])';
		say {$args->{fh}} 'whiskers_min, whiskers_max = whiskers[:, 0], whiskers[:, 1]';
		say {$args->{fh}} 'inds = np.arange(1, len(medians) + 1)';
		if ( $plot->{orientation} eq 'vertical' ) {
			say { $args->{fh} } "ax$ax"
			  . '.vlines(inds, quartile1, quartile3, color="k", linestyle="-", lw=5)';
			say { $args->{fh} } "ax$ax"
			  . '.vlines(inds, whiskers_min, whiskers_max, color="k", linestyle="-", lw=1)';
		} else {
			say { $args->{fh} } "ax$ax"
			  . '.hlines(inds, quartile1, quartile3, color="k", linestyle="-", lw=5)';
			say { $args->{fh} } "ax$ax"
			  . '.hlines(inds, whiskers_min, whiskers_max, color="k", linestyle="-", lw=1)';
		}
	}
	foreach my $key (@key_order) {
		push @xticks, "$key ("
		 . format_commas( scalar @{ $values{$key} }, '%.0u' ) . ')';
		my $mean = sum( @{ $values{$key} } ) / scalar @{ $values{$key} };
		if ( $plot->{orientation} eq 'vertical' ) {
			say { $args->{fh} } "ax$ax.plot("
			  . scalar @xticks . ", $mean"
			  . ', "ro")';    # plot mean point, which is red
		} else {                # orientation = horizontal
			say { $args->{fh} } "ax$ax.plot($mean, "
			 . scalar @xticks . ', "ro")';    # plot mean point, which is red
		}
	}
	if ( $plot->{orientation} eq 'vertical' ) {
		say { $args->{fh} } "ax$ax.set_xticks(["
		 . join( ',',   1 .. scalar @key_order ) . '], ['
		 . py_list(@xticks) . '])';
	} else {
	  say { $args->{fh} } "ax$ax.set_yticks(["
		 . join( ',',   1 .. scalar @key_order ) . '], ['
		 . py_list(@xticks) . '])';
	}
}

sub check_wide_runs {
	# Validate one group's runs for "wide", naming the offending run.
	#
	# A group is an ARRAY of [ \@x, \@y ] pairs. Getting that shape wrong --
	# passing "plot"'s single [ \@x, \@y ] pair, say -- otherwise dies deep
	# inside the writer with "Can't use string ("0") as an ARRAY ref", which
	# says nothing about which group was malformed.
	my ( $runs, $where, $current_sub ) = @_;
	if ( ref $runs ne 'ARRAY' ) {
		my $got = ref $runs ? ( ref $runs ) . ' reference' : 'a scalar';
		die "$current_sub: $where must be an ARRAY of [ \\\@x, \\\@y ] pairs, not $got";
	}
	if ( scalar @{$runs} == 0 ) {
		die "$current_sub: $where holds no runs";
	}
	foreach my $i ( 0 .. $#{$runs} ) {
		my $run = $runs->[$i];
		unless (( ref $run eq 'ARRAY' )
			&& ( scalar @{$run} == 2 )
			&& ( ref $run->[0] eq 'ARRAY' )
			&& ( ref $run->[1] eq 'ARRAY' ) ) {
			die "$current_sub: run $i of $where must be [ \\\@x, \\\@y ]; a group is an ARRAY of such pairs, so a lone pair needs one more ARRAY around it";
		}
		my $n_x = scalar @{ $run->[0] };
		my $n_y = scalar @{ $run->[1] };
		if ( $n_x != $n_y ) {
			die "$current_sub: run $i of $where has $n_x x values but $n_y y values";
		}
		if ( $n_x == 0 ) {
			die "$current_sub: run $i of $where is empty";
		}
		foreach my $axis ( 0, 1 ) {    # 0 = x, 1 = y
			my @bad = grep { !looks_like_number($_) } @{ $run->[$axis] };
			next if scalar @bad == 0;
			my $name = $axis == 0 ? 'x' : 'y';
			# only the first few, so a wholly non-numeric run does not print itself
			my $shown = join '", "', @bad[ 0 .. min( $#bad, 4 ) ];
			die "$current_sub: run $i of $where has non-numeric $name value(s): \"$shown\"";
		}
		# looks_like_number takes "inf" and "nan". An infinite x was written into
		# np.linspace as a bare name, a NameError; a NaN x sorts last and is
		# interpolated across as though it were a point. An infinite y has no
		# mean. A NaN y is a gap, which the mean below already steps around.
		my @nonfinite_x = grep { not is_finite($_) } @{ $run->[0] };
		my @infinite_y  = grep { ( not is_finite($_) ) && ( not is_nan($_) ) } @{ $run->[1] };
		if ( scalar @nonfinite_x > 0 ) {
			die "$current_sub: run $i of $where has x value(s) that are not finite: \"" . join( '", "', @nonfinite_x[ 0 .. min( $#nonfinite_x, 4 ) ] ) . '"';
		}
		if ( scalar @infinite_y > 0 ) {
			die "$current_sub: run $i of $where has infinite y value(s): \"" . join( '", "', @infinite_y[ 0 .. min( $#infinite_y, 4 ) ] ) . '"';
		}
	}
}
sub write_wide_group {
	# Emit the Python drawing one group of runs: every run faint, the mean of
	# the runs solid, and mean +/- 1 standard deviation as a ribbon.
	#
	# The runs need not share an x grid, so they are interpolated onto 101
	# evenly spaced points (the number the documentation promises) spanning
	# the group's own x range. Two properties of np.interp drive the code
	# below: it needs its sample points ascending, and by default it holds the
	# end values flat outside them. Left alone, the first silently returns a
	# flat line for a run whose x descends, and the second folds an invented
	# horizontal line into the mean and the s.d. wherever a run stops short of
	# the group's range. So each run is sorted by x first, and asked for NaN
	# outside its own range; the summary below then averages, at each point,
	# only the runs that actually reach it.
	my ($args) = @_;
	my ( $fh, $ax, $runs, $color, $label ) =
	  @{$args}{qw(fh ax runs color label)};
	my ( $min_x, $max_x ) = ( 'inf', '-inf' );
	foreach my $run ( @{$runs} ) {
		$min_x = min( $min_x, finite_values( @{ $run->[0] } ) );
		$max_x = max( $max_x, finite_values( @{ $run->[0] } ) );
	}
	my $py_color = py_str($color);
	say {$fh} 'ys = []';
	say {$fh} 'base_x = np.linspace(' . py_num($min_x) . ', ' . py_num($max_x) . ', 101)';
	foreach my $run ( @{$runs} ) {
		say {$fh} 'x = [' . py_nums( @{ $run->[0] } ) . ']';
		say {$fh} 'y = [' . py_nums( @{ $run->[1] } ) . ']';
		say {$fh} "order = np.argsort(x, kind = 'stable')";
		say {$fh} 'x = np.asarray(x)[order]';
		say {$fh} 'y = np.asarray(y)[order]';
		say {$fh} "ax$ax.plot(x, y, $py_color, alpha=0.15)";
		say {$fh} 'ys.append(np.interp(base_x, x, y, left = np.nan, right = np.nan))';
	}
	say {$fh} 'ys = np.array(ys)';
	say {$fh} 'covered = ~np.isnan(ys)';    # which runs reach each point of base_x
	say {$fh} 'n_runs = covered.sum(axis = 0)';
	say {$fh} 'divisor = np.maximum(n_runs, 1)';    # a point no run reaches would divide by 0
	say {$fh} 'mean_ys = np.where(covered, ys, 0.0).sum(axis = 0) / divisor';
	say {$fh} 'var_ys = np.where(covered, (ys - mean_ys) ** 2, 0.0).sum(axis = 0) / divisor';
	say {$fh} 'std = np.where(n_runs > 0, np.sqrt(var_ys), np.nan)';
	say {$fh} 'mean_ys = np.where(n_runs > 0, mean_ys, np.nan)';    # after var_ys, which needs the unmasked mean
	say {$fh} 'ys_upper = mean_ys + std';
	say {$fh} 'ys_lower = mean_ys - std';
	if ( defined $label ) {
		say {$fh} "ax$ax.plot(base_x, mean_ys, $py_color, label = " . py_str($label) . ')';
	} else {
		say {$fh} "ax$ax.plot(base_x, mean_ys, $py_color)";
	}
	say {$fh} "ax$ax.fill_between(base_x, ys_lower, ys_upper, color=$py_color, alpha=0.3)";
}
sub wide_helper {
	my ($args) = @_;
	my $current_sub = ( split( /::/, ( caller(0) )[3] ) )[-1]
	; # https://stackoverflow.com/questions/2559792/how-can-i-get-the-name-of-the-current-subroutine-in-perl
	if ( ref $args ne 'HASH' ) {
	  die "args must be given as a hash ref, e.g. \"$current_sub({ data => \@blah })\"";
	}
	my @reqd_args = (
	  'fh',      # e.g. $py, $fh, which will be passed by the subroutine
	  'plot',    # args to original function
	);
	my @undef_args = grep { !defined $args->{$_} } @reqd_args;
	if ( scalar @undef_args > 0 ) {
		p @undef_args;
		die "the above args are necessary for $current_sub, but were not defined.";
	}
	my @opt = (@ax_methods, @plt_methods, @fig_methods, @arg, 'ax', @{ $opt{$current_sub} });
	my $plot      = $args->{plot};
	$plot->{show_legend} = bool_option( $plot->{show_legend} // 1, 'show_legend', $current_sub );
	my @undef_opt = grep {
	  my $key = $_;
	  not grep { $_ eq $key } @opt
	} keys %{$plot};
	if ( scalar @undef_opt > 0 ) {
		bad_keyword_error({
			bad       => \@undef_opt,
			accepted  => \@opt,
			preferred => $opt{$current_sub},
			type      => $plot->{plot_type},
			sub       => $current_sub
		});
	}
	say { $args->{fh} } 'import numpy as np';
	my $ax       = $args->{ax} // '';
	my $ref_type = ref $plot->{data};
	if ( $ref_type eq 'HASH' ) {    # one labelled group per key
		if ( ( defined $plot->{color} ) && ( ref $plot->{color} ne 'HASH' ) ) {
			die "$current_sub: \"data\" is a HASH of groups, so \"color\" must be a HASH of one color per group";
		}
		# Sorted, as every other plot type orders its keys: in hash order the
		# groups, and so the legend, came out in a different order from one
		# run to the next.
		my $group_i = 0;
		foreach my $group ( sort keys %{ $plot->{data} } ) {
			check_wide_runs( $plot->{data}{$group}, "group \"$group\"", $current_sub );
			# An uncolored group takes the next color of matplotlib's own
			# cycle, "C0", "C1" and on. Every group used to default to 'b', so
			# without a "color" hash the groups could not be told apart.
			write_wide_group({
				fh    => $args->{fh},
				ax    => $ax,
				runs  => $plot->{data}{$group},
				color => $plot->{color}{$group} // 'C' . ( $group_i % 10 ),    # the default cycle has 10 colors
				label => $plot->{show_legend} ? $group : undef
			});
			$group_i++;
		}
	} elsif ( $ref_type eq 'ARRAY' ) {    # one unlabelled group
		if ( ref $plot->{color} ) {
			die "$current_sub: \"data\" is one unlabelled group, so \"color\" must be a single color, not a " . ( ref $plot->{color} ) . ' reference';
		}
		check_wide_runs( $plot->{data}, '"data"', $current_sub );
		write_wide_group({
			fh    => $args->{fh},
			ax    => $ax,
			runs  => $plot->{data},
			color => $plot->{color} // 'b',
			label => undef    # the array form carries no group name to label
		});
	} else {
	  die "$current_sub cannot take ref type \"$ref_type\" for \"data\"";
	}
}

sub print_type {
	# Whether a value has to be quoted on its way into the generated Python.
	my $str = shift;
	my $type = 'no quotes';
	if (looks_like_number($str)) { # numbers (e.g. 0.8) must not be quoted
		return 'no quotes';
	}
	# An argument list of bare values, such as "0, 10" for "ylim" or "0.5, 0, 1"
	# for "axhline", is Python rather than text. The comma tests below quoted
	# it, so a single plot's "ylim => '0, 10'" wrote plt.ylim('0, 10') and died
	# as "ValueError: too many values to unpack". None, True and False are bare
	# values too, so that
	# "ylim => 'None, 10'" leaves the bottom where matplotlib puts it.
	my @items = split /,/, $str, -1;
	if (   ( scalar @items > 1 )
		&& ( not grep { ( not looks_like_number($_) ) && ( $_ !~ m/^\h*(?:None|True|False)\h*$/ ) } @items ) ) {
		return 'no quotes';
	}
	# A single Python value: None, True or False; one bracketed group, such as
	# "(0, 10)" or "[]"; or one call, such as "np.arange(0, 1, 0.1)". Each was
	# quoted below, which a single plot always did and a subplot does now that
	# it quotes as well. The bracket must close at the very end, so that
	# "f(x), g(x)" is still text.
	if (   ( $str =~ m/^\h*(?:None|True|False)\h*$/ )
		|| ( $str =~ m/^\h*(?:[A-Za-z_][\w.]*)?(\((?:[^()]++|(?1))*\))\h*$/ )
		|| ( $str =~ m/^\h*(\[(?:[^\[\]]++|(?1))*\])\h*$/ ) ) {
		return 'no quotes';
	}
	# Text that already carries a quote of its own is Python the caller wrote
	# -- a quoted label ('"Counts, by book"', the form the documentation asks
	# for when the text holds a comma), a mathtext raw string, or a whole
	# argument list such as '0.5, 0.01, "note"'. Quoting it again nests the
	# quotes and emits plt.suptitle(''Counts, by book''), a SyntaxError. This
	# generalises the "keyword = <quote>" test below, which caught the same
	# thing only when the quote followed an "=".
	if ($str =~ m/['"]/) {
		return 'no quotes';
	}
	# A keyword argument, e.g. "hspace = 0.5" or "loc = 'upper left'": already
	# Python, whether or not its value is quoted.
	if ($str =~ m/\w\h*=\h*\S/) {
		return 'no quotes';
	}
   if ($str =~ m/^\w+$/) {
   	return 'single quotes';
   } elsif ($str =~ m/^\[\h*\-?\d.+\d\h*\]$/) {
   	return 'no quotes';
   } elsif ($str =~ m/[!@#\$\%^&*\(\)\{\}\[\]\<\>,\/\-\h:;\+=\w]+$/) {
   	return 'single quotes';
   } elsif (($str =~ m/,/) && ($str !~ m/[\]\[]/)) {
   	return 'single quotes';
   }
   return $type;
}
sub pyplot_arg {
	# A pyplot option's value as the text between the parentheses of its call.
	#
	# A single plot and a subplot both write their pyplot options through
	# this. A subplot used to write every value exactly as given, so
	# "xscale => 'log'" left plt.xscale(log) and raised "NameError: name 'log'
	# is not defined", while the same option at a single plot was quoted.
	# py_str, not "'$value'": a backslash in '...' went through as a python
	# escape, so "C:\new" came out with a newline in it.
	my ($value) = @_;
	return print_type($value) eq 'single quotes' ? py_str($value) : $value;
}
sub normalise_p {
	# "p" is a flat list of subplots: ONE array element == ONE subplot.
	#   p => [ \%h, \%h, ... ]                 each hash is its own subplot
	#   p => [ \%h, [ \%h, \%h ], \%h, ... ]   an inner array of hashes is a
	#                                          single subplot holding several
	#                                          plots on the same axes (the 1st
	#                                          hash is the base plot, the rest
	#                                          are "add"itions/overlays)
	# The plain-hash and inner-array forms may be mixed freely in one "p".
	# Using "p" means top-level "plot_type"/"data" are not used. If no grid is
	# given, the subplots are laid out on an automatically-sized near-square
	# grid; pass nrow(s)/ncol(s) to override.
	my ( $args, $current_sub ) = @_;
	$current_sub = $current_sub // 'plt';
	my $p = delete $args->{p};
	if ( ref $p ne 'ARRAY' ) {
		die "$current_sub: \"p\" must be an ARRAY reference (one element per subplot)";
	}
	if ( scalar @{$p} == 0 ) {
		die "$current_sub: \"p\" is empty";
	}
	# "p" supersedes the older interface; forbid mixing to avoid ambiguity
	foreach my $clash ( grep { defined $args->{$_} } ( 'plot_type', 'data', 'plots', 'add' ) ) {
		die "$current_sub: \"$clash\" cannot be combined with \"p\"";
	}
	my @plots;
	my $i = 0;
	foreach my $subplot ( @{$p} ) {
		my $ref = ref $subplot;
		if ( $ref eq 'HASH' ) {                       # one subplot, one plot
			push @plots, { %{$subplot} };             # shallow copy; don't mutate caller
		} elsif ( $ref eq 'ARRAY' ) {                 # one subplot, several overlaid plots
			if ( scalar @{$subplot} == 0 ) {
				die "$current_sub: subplot $i in \"p\" is an empty array";
			}
			my @g    = @{$subplot};
			my $main = shift @g;                      # 1st hash is the base plot
			foreach my $plot ( $main, @g ) {
				if ( ref $plot ne 'HASH' ) {
					die "$current_sub: subplot $i in \"p\": every plot must be a HASH reference";
				}
			}
			my %plot = %{$main};                      # shallow copy of the base plot
			# the rest overlay on the same axes. A new array, not a push: the
			# copy above shares the base plot's own "add" array with the caller.
			$plot{add} = [ @{ $plot{add} // [] }, @g ] if scalar @g;
			push @plots, \%plot;
		} else {
			die "$current_sub: subplot $i in \"p\" must be a HASH reference (one plot) or an ARRAY of HASH references (overlaid plots), not a \"$ref\" reference";
		}
		$i++;
	}
	$args->{plots} = \@plots;
	# convenience: choose a subplot grid. With neither dimension given, use a
	# near-square grid; with exactly one given (and positive), derive the other
	# so e.g. "ncols => 1" stacks the subplots in a single column. Empty
	# trailing cells are pruned later by the engine.
	my $n     = scalar @plots;
	my $ncols = $args->{ncols} // $args->{ncol};
	my $nrows = $args->{nrows} // $args->{nrow};
	if ( ( not defined $ncols ) && ( not defined $nrows ) ) {
		$ncols = 1;
		$ncols++ while ( $ncols * $ncols ) < $n;             # ceil(sqrt $n), no floats
		$args->{ncols} = $ncols;
		$args->{nrows} = int( ( $n + $ncols - 1 ) / $ncols );  # ceil($n / $ncols)
	} elsif ( ( not defined $ncols ) && ( $nrows > 0 ) ) {   # only rows given
		$args->{ncols} = int( ( $n + $nrows - 1 ) / $nrows );
	} elsif ( ( not defined $nrows ) && ( $ncols > 0 ) ) {   # only cols given
		$args->{nrows} = int( ( $n + $ncols - 1 ) / $ncols );
	}
	return $args;
}
# The interpreters tried on MSWin32, in order. "python" first, because it is
# what a stock install from python.org and an activated venv both put on PATH,
# and the venv is the one that has matplotlib; "py -3", the launcher, next,
# since an install can leave python off PATH but always installs the
# launcher; "python3" last, for MSYS2 and the like. A stock Windows install has
# no "python3" at all, which is why running it failed wherever Python *was*
# present, and never showed up in a CPAN Testers report because the smokers
# have none.
my @windows_python_candidates = ( ['python'], [ 'py', '-3' ], ['python3'] );
# The command plt runs, as a list for system(). undef = not yet looked for;
# [] = looked for, and none found. A package variable rather than a lexical so
# that the test suite can point it at a stand-in interpreter.
our $python_command;
sub python_command {
	# The interpreter plt runs scripts with, as a list. $ENV{MATPLOTLIB_SIMPLE_PYTHON},
	# when set and not empty, is that interpreter, taken whole and neither
	# searched for nor checked: it names a venv or a module-loaded Python
	# without changing PATH, and is not split on spaces because a path such as
	# "C:\Program Files\Python312\python.exe" has them. One that does not
	# run is reported by plt as "failed to start". Otherwise it is
	# ('python3') on everything but MSWin32, as it always was, and there the
	# first of @windows_python_candidates that reports itself as Python 3, or
	# an empty list if none does. The result is kept, so the search runs once.
	#
	# "--version" rather than trusting that the name resolves: on Windows 10
	# and 11 "python" with no Python installed is a Microsoft Store stub,
	# which prints "Python was not found" and exits 9009. Both streams are
	# read, since Python 3 before 3.4 printed its version to STDERR.
	return @{$python_command} if defined $python_command;
	if ( defined $ENV{MATPLOTLIB_SIMPLE_PYTHON} && $ENV{MATPLOTLIB_SIMPLE_PYTHON} ne '' ) {
		$python_command = [ $ENV{MATPLOTLIB_SIMPLE_PYTHON} ];
		return @{$python_command};
	}
	if ( $^O ne 'MSWin32' ) {
		$python_command = ['python3'];
		return @{$python_command};
	}
	foreach my $candidate (@windows_python_candidates) {
		my ( $out, $err, $status ) = capture {
			no warnings 'exec';    # a candidate that is not installed is expected; see the call in plt
			system( @{$candidate}, '--version' );
		};
		next unless ( $status == 0 ) && ( "$out$err" =~ m/^Python 3\./m );
		$python_command = [ @{$candidate} ];
		return @{$python_command};
	}
	$python_command = [];
	return ();
}
sub copy_plot_hashes {
	# A copy of plt's arguments, deep enough that nothing plt does is seen by
	# the caller.
	#
	# plt and its helpers write into the hashes they are given: "add" is
	# deleted once drawn, "title" is renamed "set_title", a subplot is told
	# whether to draw its colorbar, and array "data" is rewrapped as a hash.
	# Under plt({ ... }) those were the caller's own hashes, so the same hash
	# drawn twice lost its overlays the second time. The hashes are copied,
	# at every level plt writes to -- the top, each subplot, each "add" graph --
	# and the data inside them is not: it is only read, and can be large.
	# Anything of the wrong shape is passed through as it is, for the checks
	# in plt to refuse by name.
	#
	# "p" is copied too, subplot by subplot and overlay by overlay. It was not,
	# and normalise_p copies only the subplot hashes it builds, so an overlay
	# drawn through "p" -- the 2nd hash of an inner array, or an "add" graph --
	# was the caller's own: a hist overlay came back with its array "data"
	# rewrapped as { A => [...] } and a "plot_type" it had not been given.
	my ($args) = @_;
	my $copy_plot = sub {
		my ($plot) = @_;
		return $plot unless ref $plot eq 'HASH';
		$plot = { %{$plot} };
		if ( ref $plot->{add} eq 'ARRAY' ) {
			$plot->{add} = [ map { ref $_ eq 'HASH' ? { %{$_} } : $_ } @{ $plot->{add} } ];
		}
		return $plot;
	};
	my $copy = $copy_plot->($args);
	if ( ref $copy->{plots} eq 'ARRAY' ) {
		$copy->{plots} = [ map { $copy_plot->($_) } @{ $copy->{plots} } ];
	}
	if ( ref $copy->{p} eq 'ARRAY' ) {
		$copy->{p} = [
			map { ref $_ eq 'ARRAY' ? [ map { $copy_plot->($_) } @{$_} ] : $copy_plot->($_) } @{ $copy->{p} }
		];
	}
	return $copy;
}
sub refuse_dotted_keywords {
	# Die naming every keyword given in its pre-0.319 dotted spelling, where
	# it was given, and what it is called now.
	#
	# Most of them would be refused anyway, with the new name among the
	# suggestions, since similar_keywords ignores separators. "plot.type" and
	# "output.file" would not: plt looks for "plot_type" and "output_file"
	# before it checks any keyword, so a script written for 0.318 died with
	# "either "show" or "output_file" must be defined", which never mentions
	# the key the caller actually wrote. This runs first, so that every old
	# script fails the same way. It visits the levels copy_plot_hashes copies.
	my ( $args, $current_sub ) = @_;
	my @found;    # "old" => "new" at <where>, one per dotted key
	my $check_keys = sub {
		my ( $plot, $where ) = @_;
		return unless ref $plot eq 'HASH';
		foreach my $key ( sort grep { exists $undotted_keyword{$_} } keys %{$plot} ) {
			push @found, "\"$key\" is now \"$undotted_keyword{$key}\"$where";
		}
	};
	my $check = sub {    # a plot and its "add" graphs, which do not nest
		my ( $plot, $where ) = @_;
		$check_keys->( $plot, $where );
		return unless ( ref $plot eq 'HASH' ) && ( ref $plot->{add} eq 'ARRAY' );
		foreach my $i ( 0 .. $#{ $plot->{add} } ) {
			$check_keys->( $plot->{add}[$i], " in \"add\" graph $i$where" );
		}
	};
	$check->( $args, '' );
	if ( ref $args->{plots} eq 'ARRAY' ) {
		$check->( $args->{plots}[$_], " at subplot $_" ) foreach 0 .. $#{ $args->{plots} };
	}
	if ( ref $args->{p} eq 'ARRAY' ) {
		foreach my $i ( 0 .. $#{ $args->{p} } ) {
			my $entry = $args->{p}[$i];
			my @graphs = ref $entry eq 'ARRAY' ? @{$entry} : ($entry);
			$check->( $_, " at \"p\" entry $i" ) foreach @graphs;
		}
	}
	return if scalar @found == 0;
	die "$current_sub: keywords are spelled with \"_\", not \".\", since 0.319: "
	 . join( '; ', @found );
}
# "df": a data frame given whole, with the columns to plot named by role, in
# place of "data" built by hand. The four shapes are those of Stats::LikeR
# (lib/Stats/LikeR.pm, _df_shape, Stats::LikeR 0.3213): an array of hashes (one
# hash per row), a hash of arrays (one array per column), a hash of hashes (row
# name => { column => value }) and an array of arrays (columns by 0-based
# position). They are recognised by their structure, so the frame can come from
# anywhere; Stats::LikeR is not loaded.
#
# frames_to_data rewrites every plot hash holding "df" into the "data" its
# plot_type already takes, before anything else in plt looks at it, so no
# helper knows that a frame was ever given.
#
# plot_type => the roles it reads columns from:
#   take => the roles it accepts
#   need => the roles it cannot be drawn without
#   many => the one role that may name several columns, as an array ref
#   rows => 1 if "x" may be left out of a hash-of-hashes frame, whose row names
#           are then the labels
#   each => 1 if each column is one distribution of its own: "many" may be left
#           out, for every column of numbers, and without "by" the columns
#           need not be the same length, since no row is read across them
my %frame_roles = (
	bar           => { take => [ 'x', 'y', 'by' ], need => ['y'],        many => 'y', rows => 1 },
	barh          => { take => [ 'x', 'y', 'by' ], need => ['y'],        many => 'y', rows => 1 },
	boxplot       => { take => [ 'y', 'by' ],      need => ['y'],        many => 'y' },
	colored_table => { take => [ 'x', 'y' ],       need => [],           many => 'y', rows => 1 },
	hexbin        => { take => [ 'x', 'y' ],       need => [ 'x', 'y' ] },
	hist          => { take => [ 'x', 'by' ],      need => [],           many => 'x', each => 1 },
	hist2d        => { take => [ 'x', 'y' ],       need => [ 'x', 'y' ] },
	pie           => { take => [ 'x', 'y' ],       need => ['y'],                     rows => 1 },
	plot          => { take => [ 'x', 'y', 'by' ], need => [ 'x', 'y' ], many => 'y' },
	scatter       => { take => [ 'x', 'y', 'by' ], need => [ 'x', 'y' ] },
	violin        => { take => [ 'y', 'by' ],      need => [],           many => 'y', each => 1 },
	violinplot    => { take => [ 'y', 'by' ],      need => [],           many => 'y', each => 1 },
);
my @frame_keys = ( 'df', 'x', 'y', 'by' );
sub frame_shape {
	# "AoA", "AoH", "HoA" or "HoH": which of the four shapes a frame is.
	my ( $df, $where ) = @_;
	my $ref = ref $df;
	if ( $ref eq 'ARRAY' ) {
		foreach my $row ( @{$df} ) {
			next unless defined $row;
			return 'AoA' if ref $row eq 'ARRAY';
			return 'AoH' if ref $row eq 'HASH';
			die "\"df\"$where is an array, so its rows must be ARRAY (AoA) or HASH (AoH) references, but one is "
			 . ( ref $row ? 'a ' . ref $row . ' reference' : "\"$row\"" );
		}
		die "\"df\"$where has no rows";
	}
	if ( $ref eq 'HASH' ) {
		die "\"df\"$where has no columns" if scalar keys %{$df} == 0;
		my %kinds = map { ( ref $_ ) => 1 } values %{$df};
		my @kinds = sort keys %kinds;
		return 'HoA' if "@kinds" eq 'ARRAY';
		return 'HoH' if "@kinds" eq 'HASH';
		die "\"df\"$where is a hash, so its values must all be ARRAY (HoA, column => values) or all HASH (HoH, row => { column => value }) references, but they are: "
		 . join( ', ', map { $_ eq '' ? 'not references' : $_ } @kinds );
	}
	die "\"df\"$where must be an ARRAY (AoA, AoH) or HASH (HoA, HoH) reference, not "
	 . ( $ref eq '' ? 'a plain value' : "a $ref reference" );
}
sub frame_column_names {
	# Every column name of a frame, sorted; for an AoA, every position.
	my ( $df, $shape ) = @_;
	return sort keys %{$df} if $shape eq 'HoA';
	if ( $shape eq 'AoA' ) {
		my $width = max( 0, map { scalar @{$_} } grep { defined } @{$df} );
		return 0 .. $width - 1;
	}
	my %seen;
	foreach my $row ( $shape eq 'HoH' ? values %{$df} : @{$df} ) {
		next unless ref $row eq 'HASH';
		$seen{$_} = 1 foreach keys %{$row};
	}
	return sort keys %seen;
}
sub frame_columns {
	# The named columns of a frame as arrays, row by row in step with one
	# another, and the row names, which only a hash of hashes has.
	#
	# A row's cells are all taken from that row in the one pass, rather than a
	# column at a time, so that x and y cannot come from different rows
	# whatever the shape. Rows run in the frame's own order; a hash of hashes
	# has none, and its rows are taken in the sorted order of their names,
	# which is the order Stats::LikeR's vals() and view() give them. A column
	# that no row has is refused by name, as Stats::LikeR refuses it.
	#
	# $ragged is true when no row is read across the columns, so that the
	# columns of a hash of arrays need not be the same length; Stats::LikeR's
	# group_by gives one column per group, each as long as its group.
	#
	# $given maps a column to the option that named it ("x", "y", "by" or
	# "color_key"), and $sub is the caller's name; both are optional, and
	# serve only to say, when a column is missing, which option named it.
	my ( $df, $shape, $columns, $where, $ragged, $given, $sub ) = @_;
	$given //= {};
	# how a missing column is introduced: 'scatter: "dG", given as "x",'
	my $named = sub {
		my ($column) = @_;
		return ( defined $sub ? "$sub: " : '' ) . "\"$column\""
		 . ( defined $given->{$column} ? ", given as \"$given->{$column}\"," : '' );
	};
	my %seen;
	my @columns = grep { not $seen{$_}++ } @{$columns};
	my ( %out, @row_names );
	my $missing = sub {
		my ($column) = @_;
		my @have  = frame_column_names( $df, $shape );
		my @close = similar_keywords( $column, \@have );
		# 20: enough to show a typical table whole, while a wide one from a
		# spreadsheet does not bury the message under hundreds of names.
		my $shown = scalar @have > 20 ? join( ', ', @have[ 0 .. 19 ] ) . ', ...' : join( ', ', @have );
		die $named->($column) . " is not a column in the dataframe \"df\"$where"
		 . ( scalar @close ? '; perhaps you meant ' . join( ' or ', map { "\"$_\"" } @close ) : '' )
		 . ". Its columns are: $shown";
	};
	if ( $shape eq 'HoA' ) {
		foreach my $column (@columns) {
			$missing->($column) unless exists $df->{$column};
			$out{$column} = $df->{$column};    # only read from here on, so not copied
		}
		my %n_rows = map { $_ => scalar @{ $df->{$_} } } @columns;
		my %lengths = map { $_ => 1 } values %n_rows;
		if ( ( not $ragged ) && ( scalar keys %lengths > 1 ) ) {
			die "the columns of \"df\"$where must all have the same number of rows, but they have "
			 . join( ', ', map { "\"$_\" $n_rows{$_}" } @columns );
		}
		return ( \%out, [] );
	}
	if ( $shape eq 'AoA' ) {
		my $width = max( 0, map { scalar @{$_} } grep { defined } @{$df} );
		my %position;
		foreach my $column (@columns) {
			if ( ( $column !~ m/^-?\d+$/ ) || ( $column >= $width ) || ( $column < -$width ) ) {
				die $named->($column) . " is not a column in the dataframe \"df\"$where, which is an array of arrays, whose columns are 0-based positions from 0 to " . ( $width - 1 )
				 . ' (or negative, from the end)';
			}
			$position{$column} = $column < 0 ? $width + $column : $column;
			$out{$column} = [];
		}
		my $i = 0;
		foreach my $row ( @{$df} ) {
			# An undefined row is a row with no values, left out by the caller's
			# plot like any other row missing one. frame_shape and
			# frame_column_names already stepped over it, and this died on it.
			if ( not defined $row ) {
				push @{ $out{$_} }, undef foreach @columns;
				$i++;
				next;
			}
			die "row $i of \"df\"$where is not an ARRAY reference" unless ref $row eq 'ARRAY';
			push @{ $out{$_} }, $row->[ $position{$_} ] foreach @columns;
			$i++;
		}
		return ( \%out, [] );
	}
	my @rows;
	if ( $shape eq 'HoH' ) {
		@row_names = sort keys %{$df};
		@rows      = @{$df}{@row_names};
	} else {
		@rows = @{$df};
	}
	my %found;
	foreach my $i ( 0 .. $#rows ) {
		if ( ( $shape eq 'AoH' ) && ( not defined $rows[$i] ) ) {    # as for an array of arrays above
			push @{ $out{$_} }, undef foreach @columns;
			next;
		}
		if ( ref $rows[$i] ne 'HASH' ) {
			die 'row ' . ( $shape eq 'HoH' ? "\"$row_names[$i]\"" : $i ) . " of \"df\"$where is not a HASH reference";
		}
		foreach my $column (@columns) {
			$found{$column} = 1 if exists $rows[$i]{$column};
			push @{ $out{$column} }, $rows[$i]{$column};
		}
	}
	foreach my $column (@columns) {
		$missing->($column) unless $found{$column};
	}
	return ( \%out, \@row_names );
}
sub complete_rows {
	# The indices of the rows that have a value in every one of the columns.
	my ( $cells, $columns ) = @_;
	my $n = scalar @{ $cells->{ $columns->[0] } };
	return grep {
		my $i = $_;
		not grep { not defined $cells->{$_}[$i] } @{$columns}
	} 0 .. $n - 1;
}
sub check_dropped {
	# Say how many rows were left out for want of a value, as ggplot2's
	# "Removed 3 rows containing missing values" does: a missing value cannot
	# be drawn, and refusing every frame with one in it would refuse most real
	# data, but rows leaving a plot without a word would be worse.
	#
	# Die if that was every row. Only plot without "by", and scatter, hexbin
	# and hist2d, checked for themselves, and scatter's message left out the
	# "by" column; the rest made an empty "data" and died as '"data" is an
	# empty hash', about an option the caller had never given.
	my ( $n_kept, $n, $columns, $where, $sub ) = @_;
	if ( $n_kept == 0 ) {
		my @names = map { "\"$_\"" } @{$columns};
		die "$sub: no row of \"df\"$where has a value in "
		 . ( scalar @names == 1 ? $names[0] : scalar @names == 2 ? "both $names[0] and $names[1]" : 'every one of ' . join( ', ', @names ) );
	}
	return if $n_kept == $n;
	warn "$sub: left out " . ( $n - $n_kept ) . " of $n rows of \"df\"$where, which have no value in "
	 . join( ' or ', map { "\"$_\"" } @{$columns} ) . "\n";
}
sub group_order {
	# The distinct values of a grouping column, in numeric order when every
	# one is a number and in string order otherwise: 2 before 10, as a reader
	# expects, where the sorted order of keys would put 10 first.
	my @values = @_;
	my %seen;
	my @groups = grep { not $seen{$_}++ } @values;
	return ( grep { not looks_like_number($_) } @groups )
	 ? sort @groups
	 : sort { $a <=> $b } @groups;
}
sub first_seen {
	# The distinct values of a column, in the order of the rows they first
	# appear in.
	my %seen;
	return grep { not $seen{$_}++ } @_;
}
sub frame_to_data {
	# Rewrite one plot hash holding "df" into the "data" its plot_type takes,
	# deleting "df", "x", "y" and "by", and filling in the options that say
	# what the columns were: "key_order" or "keys", so that x is drawn on the
	# x axis rather than wherever the sorted names put it, and the axis
	# labels, which the caller's own still override.
	#
	# The plot hash is plt's own copy, made by copy_plot_hashes, so writing to
	# it leaves the caller's as it was. The frame is only read.
	my ( $plot, $type, $where, $sub ) = @_;
	if ( not exists $plot->{df} ) {
		my @stray = grep { exists $plot->{$_} } ( 'x', 'y', 'by' );
		return unless scalar @stray;
		die "$sub: " . join( ', ', map { "\"$_\"" } @stray ) . "$where name" . ( scalar @stray == 1 ? 's' : '' )
		 . ' columns of "df", but no "df" was given';
	}
	die "$sub: \"df\"$where is undefined" unless defined $plot->{df};
	die "$sub: \"df\" and \"data\" cannot both be given$where; \"df\" is turned into \"data\"" if exists $plot->{data};
	die "$sub: \"df\"$where needs a \"plot_type\" to say how its columns are drawn" unless defined $type;
	check_plot_type({ type => $type, where => ( $where eq '' ? undef : substr( $where, 1 ) ) });
	my $roles = $frame_roles{$type};
	if ( not defined $roles ) {
		die "$sub: plot_type \"$type\"$where does not take \"df\"; give it \"data\". The plot types that take \"df\" are: "
		 . join( ', ', sort keys %frame_roles );
	}
	my %takes = map { $_ => 1 } @{ $roles->{take} };
	my @refused = grep { ( exists $plot->{$_} ) && ( not $takes{$_} ) } ( 'x', 'y', 'by' );
	if ( scalar @refused ) {
		die "$sub: plot_type \"$type\"$where takes its columns of \"df\" in "
		 . join( ' and ', map { "\"$_\"" } @{ $roles->{take} } ) . ', not in ' . join( ' or ', map { "\"$_\"" } @refused );
	}
	my $df    = $plot->{df};
	my $shape = frame_shape( $df, $where );
	my @need  = @{ $roles->{need} };
	push @need, 'x' if ( $takes{x} ) && ( $roles->{rows} ) && ( $shape ne 'HoH' );
	push @need, $roles->{many} if ( $roles->{each} ) && ( defined $plot->{by} );    # the one column "by" splits
	my @absent = grep { not defined $plot->{$_} } @need;
	if ( scalar @absent ) {
		die "$sub: plot_type \"$type\"$where needs " . join( ' and ', map { "\"$_\"" } @absent ) . ' to name '
		 . ( scalar @absent == 1 ? 'a column' : 'columns' ) . ' of "df"'
		 . ( ( grep { $_ eq 'x' } @absent ) && ( $roles->{rows} ) ? '; only a hash of hashes has row names to label it by instead' : '' );
	}
	# Each role as a list of column names; only $roles->{many} may hold more than one.
	my %col;
	foreach my $role ( 'x', 'y', 'by' ) {
		next unless defined $plot->{$role};
		my $value = $plot->{$role};
		my @names = ref $value eq 'ARRAY' ? @{$value} : ($value);
		if ( ( ref $value ne '' ) && ( ref $value ne 'ARRAY' ) ) {
			die "$sub: \"$role\"$where names a column of \"df\", or for \"" . ( $roles->{many} // $role ) . '" an array of them, not a ' . ref($value) . ' reference';
		}
		die "$sub: \"$role\"$where is an empty array" if scalar @names == 0;
		my @bad = grep { ( not defined $_ ) || ( ref $_ ) } @names;
		die "$sub: \"$role\"$where holds something that is not a column name" if scalar @bad;
		if ( ( scalar @names > 1 ) && ( ( $roles->{many} // '' ) ne $role ) ) {
			die "$sub: \"$role\"$where can name only one column for plot_type \"$type\""
			 . ( defined $roles->{many} ? "; \"$roles->{many}\" is the one that takes several" : '' );
		}
		$col{$role} = \@names;
	}
	my $many = $roles->{many} // '';
	if ( ( defined $col{by} ) && ( defined $col{$many} ) && ( scalar @{ $col{$many} } > 1 ) ) {
		die "$sub: \"by\"$where splits one column into groups, so \"$many\" can name only one column when \"by\" is given";
	}
	my $color_key = ( $type eq 'scatter' ) ? $plot->{color_key} : undef;    # a column too, for scatter
	if ( ( defined $color_key ) && ( ref $color_key ) ) {
		die "$sub: \"color_key\"$where names one column of \"df\"";
	}
	my @used = ( map { @{ $col{$_} // [] } } ( 'x', 'y', 'by' ) );
	push @used, $color_key if defined $color_key;
	my %n_named;
	my @twice = grep { $n_named{$_}++ == 1 } @used;
	if ( scalar @twice ) {
		# The columns become the keys of "data", so one named twice would be
		# drawn against itself, or silently once.
		die "$sub: " . join( ', ', map { "\"$_\"" } @twice ) . "$where is named more than once among the columns of \"df\" to plot";
	}
	foreach my $option ( grep { exists $plot->{$_} } ( 'keys', ( $type =~ m/^(?:hexbin|hist2d)$/ ? 'key_order' : () ) ) ) {
		die "$sub: \"$option\"$where cannot be given with \"df\": \"x\" and \"y\" already say which column goes on which axis";
	}
	my @default_y;
	if ( ( $type eq 'colored_table' ) && ( not defined $col{y} ) ) {
		my %is_x = map { $_ => 1 } @{ $col{x} // [] };
		@default_y = grep { not $is_x{$_} } frame_column_names( $df, $shape );
		$col{y} = \@default_y;
		@used = ( @{ $col{x} // [] }, @default_y );
	}
	my $every_column = ( $roles->{each} ) && ( not defined $col{$many} );
	@used = frame_column_names( $df, $shape ) if $every_column;
	my %given;
	foreach my $role ( 'x', 'y', 'by' ) {
		$given{$_} = $role foreach @{ $col{$role} // [] };
	}
	$given{$color_key} = 'color_key' if defined $color_key;
	my ( $cells, $row_names ) = frame_columns( $df, $shape, \@used, $where, $roles->{each} && ( not defined $col{by} ), \%given, $sub );
	# the longest column, as the columns of "each" need not be the same length
	my $n_rows = scalar( @{$row_names} ) || max( 0, map { scalar @{ $cells->{$_} } } @used );
	die "\"df\"$where has no rows" if $n_rows == 0;
	if ($every_column) {
		# Every column that holds numbers and nothing else, as pandas' DataFrame.hist
		# and .boxplot take every numeric column: a column of names or of
		# categories is not a distribution, and most tables have one.
		my @numeric = grep {
			my @values = grep { defined } @{ $cells->{$_} };
			( scalar @values ) && ( not grep { not looks_like_number($_) } @values );
		} @used;
		die "$sub: \"df\"$where has no column of numbers to draw" if scalar @numeric == 0;
		# in numeric order when every name is a number, as the groups of
		# group_by are, so that 4, 6 and 8 cylinders are drawn in that order
		$col{$many} = [ group_order(@numeric) ];
	}
	my ($x)  = @{ $col{x}  // [] };
	my ($by) = @{ $col{by} // [] };
	my @y    = @{ $col{y}  // [] };
	my %data;
	my $label_axis = sub {    # default an axis label to a column name; py_str because a column name is data, see hist2d_helper
		my ( $axis, $column ) = @_;
		return unless defined $column;
		return if ( defined $plot->{$axis} ) || ( defined $plot->{"set_$axis"} );
		$plot->{$axis} = py_str($column);
	};
	if ( $type =~ m/^(?:bar|barh|pie|colored_table)$/ ) {
		# The labels: column "x", or the row names of a hash of hashes.
		my $labels = defined $x ? $cells->{$x} : $row_names;
		if ( $type eq 'colored_table' ) {
			# $x is undefined for a hash of hashes labelled by its row names,
			# and the message died as "Use of uninitialized value $x".
			if ( scalar @y == 0 ) {
				die "$sub: \"df\"$where has no columns " . ( defined $x ? "but \"$x\" " : '' ) . 'to put in the table';
			}
			my %row;
			foreach my $i ( grep { defined $labels->[$_] } 0 .. $n_rows - 1 ) {
				my $label = $labels->[$i];
				die "$sub: \"$label\" appears in more than one row of \"$x\" in \"df\"$where, and colored_table has one row per label" if $row{$label};
				# An undefined cell is left out, which colored_table draws as undefined.
				$row{$label} = { map { $_ => $cells->{$_}[$i] } grep { defined $cells->{$_}[$i] } @y };
			}
			check_dropped( scalar keys %row, $n_rows, [$x], $where, $sub ) if defined $x;
			%data = %row;
		} else {
			my @value_cols = ( @y, ( defined $by ? $by : () ) );
			my @kept = grep { defined $labels->[$_] } complete_rows( $cells, \@value_cols );
			check_dropped( scalar @kept, $n_rows, [ ( defined $x ? $x : () ), @value_cols ], $where, $sub );
			my @labels = map { $labels->[$_] } @kept;
			my $what   = $type eq 'pie' ? 'wedge' : 'bar';
			if ( defined $by ) {
				# A pivot: one series per group, one bar per label in each.
				my @groups = group_order( map { $cells->{$by}[$_] } @kept );
				my %cell;
				foreach my $i (@kept) {
					my ( $label, $group ) = ( $labels->[$i], $cells->{$by}[$i] );
					if ( exists $cell{$label}{$group} ) {
						die "$sub: more than one row of \"df\"$where has \"$x\" = \"$label\" and \"$by\" = \"$group\", and a grouped $type draws one bar for each pair: aggregate the rows first, e.g. with Stats::LikeR's agg or pivot_table";
					}
					$cell{$label}{$group} = $cells->{ $y[0] }[$i];
				}
				my @labels_once = first_seen(@labels);
				my @gaps;
				foreach my $label (@labels_once) {
					push @gaps, map { "\"$label\"/\"$_\"" } grep { not exists $cell{$label}{$_} } @groups;
					$data{$label} = [ map { $cell{$label}{$_} } @groups ];
				}
				if ( scalar @gaps ) {
					splice @gaps, 5, scalar(@gaps) - 5, '...' if scalar @gaps > 5;    # enough to see the pattern
					die "$sub: no row of \"df\"$where has a value for " . join( ', ', @gaps )
					 . ' (' . ( defined $x ? "\"$x\"" : 'row name' ) . "/\"$by\"), and a grouped $type needs one for every pair";
				}
				$plot->{label} = $plot->{label} // [@groups];
				if ( ref $plot->{color} eq 'HASH' ) {
					# The series are the groups, so a color keyed by group can be put in their order here.
					my @uncolored = grep { not defined $plot->{color}{$_} } @groups;
					die "$sub: \"color\"$where has no color for the groups " . join( ', ', map { "\"$_\"" } @uncolored ) if scalar @uncolored;
					$plot->{color} = [ @{ $plot->{color} }{@groups} ];
				}
			} else {
				my %row_of;
				foreach my $i (@kept) {
					my $label = $labels->[$i];
					if ( exists $row_of{$label} ) {
						die "$sub: \"$label\" appears in more than one row of \"$x\" in \"df\"$where, and $type draws one $what per label: aggregate the rows first, e.g. with Stats::LikeR's agg";
					}
					$row_of{$label} = $i;
					$data{$label} = scalar @y == 1 ? $cells->{ $y[0] }[$i] : [ map { $cells->{$_}[$i] } @y ];
				}
				if ( scalar @y > 1 ) {
					$plot->{label} = $plot->{label} // [@y];
					if ( ref $plot->{color} eq 'HASH' ) {
						my @uncolored = grep { not defined $plot->{color}{$_} } @y;
						die "$sub: \"color\"$where has no color for the columns " . join( ', ', map { "\"$_\"" } @uncolored ) if scalar @uncolored;
						$plot->{color} = [ @{ $plot->{color} }{@y} ];
					}
				}
			}
			# The rows of a table are in an order of their own, which the
			# sorted labels would lose.
			$plot->{key_order} = $plot->{key_order} // [ first_seen(@labels) ];
			if ( $type ne 'pie' ) {
				my ( $label_axis_name, $value_axis_name ) = $type eq 'barh' ? ( 'ylabel', 'xlabel' ) : ( 'xlabel', 'ylabel' );
				$label_axis->( $label_axis_name, $x );
				$label_axis->( $value_axis_name, scalar @y == 1 ? $y[0] : undef );
			}
		}
	} elsif ( $type =~ m/^(?:hist|boxplot|violin|violinplot)$/ ) {
		# One distribution per column, or one per group of a single column.
		my @value_cols = $type eq 'hist' ? @{ $col{x} } : @y;
		if ( defined $by ) {
			my $column = $value_cols[0];
			my @kept = complete_rows( $cells, [ $column, $by ] );
			check_dropped( scalar @kept, $n_rows, [ $column, $by ], $where, $sub );
			push @{ $data{ $cells->{$by}[$_] } }, $cells->{$column}[$_] foreach @kept;
			$plot->{key_order} = $plot->{key_order} // [ group_order( keys %data ) ];
		} else {
			# Column by column: a value missing from one column says nothing about the others.
			foreach my $column (@value_cols) {
				$data{$column} = [ grep { defined } @{ $cells->{$column} } ];
				check_dropped( scalar @{ $data{$column} }, scalar @{ $cells->{$column} }, [$column], $where, $sub );
			}
			$plot->{key_order} = $plot->{key_order} // [@value_cols];
		}
		my $values = scalar @value_cols == 1 ? $value_cols[0] : undef;
		if ( $type eq 'hist' ) {
			$label_axis->( ( $plot->{orientation} // '' ) eq 'horizontal' ? 'ylabel' : 'xlabel', $values );
		} else {
			my $horizontal = ( $plot->{orientation} // '' ) eq 'horizontal';
			$label_axis->( $horizontal ? 'xlabel' : 'ylabel', $values );
			$label_axis->( $horizontal ? 'ylabel' : 'xlabel', $by );
		}
	} elsif ( $type =~ m/^(?:scatter|hist2d|hexbin)$/ ) {
		my @axes = ( $x, $y[0], ( defined $color_key ? $color_key : () ) );
		my @kept = complete_rows( $cells, [ @axes, ( defined $by ? $by : () ) ] );
		check_dropped( scalar @kept, $n_rows, [ @axes, ( defined $by ? $by : () ) ], $where, $sub );
		if ( defined $by ) {
			foreach my $i (@kept) {
				push @{ $data{ $cells->{$by}[$i] }{$_} }, $cells->{$_}[$i] foreach @axes;
			}
			# in numeric order when the groups are numbers, as for every other
			# type; the sets of a scatter were drawn in sorted order, 10 before 2
			$plot->{key_order} = $plot->{key_order} // [ group_order( keys %data ) ] if $type eq 'scatter';
		} else {
			$data{$_} = [ @{ $cells->{$_} }[@kept] ] foreach @axes;
		}
		# The helpers' labels are taken from these, so they need not be set here.
		if ( $type eq 'scatter' ) {
			$plot->{'keys'} = [@axes];
		} else {
			$plot->{key_order} = [ $x, $y[0] ];
		}
	} elsif ( $type eq 'plot' ) {
		# One line per y column, or per group: each in the order of x, as a
		# line through a table's rows is meant to be read, the ties in row order.
		my $line = sub {
			my ( $y_col, @rows ) = @_;
			my @xs = @{ $cells->{$x} }[@rows];
			if ( not grep { not looks_like_number($_) } @xs ) {    # a word is refused by plot_helper, by name
				@rows = @rows[ sort { $xs[$a] <=> $xs[$b] || $a <=> $b } 0 .. $#rows ];
			}
			return [ [ @{ $cells->{$x} }[@rows] ], [ @{ $cells->{$y_col} }[@rows] ] ];
		};
		if ( defined $by ) {
			my @kept = complete_rows( $cells, [ $x, $y[0], $by ] );
			check_dropped( scalar @kept, $n_rows, [ $x, $y[0], $by ], $where, $sub );
			my %rows_of;
			push @{ $rows_of{ $cells->{$by}[$_] } }, $_ foreach @kept;
			$data{$_} = $line->( $y[0], @{ $rows_of{$_} } ) foreach keys %rows_of;
			$plot->{key_order} = $plot->{key_order} // [ group_order( keys %rows_of ) ];
		} else {
			foreach my $y_col (@y) {
				my @kept = complete_rows( $cells, [ $x, $y_col ] );
				check_dropped( scalar @kept, $n_rows, [ $x, $y_col ], $where, $sub );
				$data{$y_col} = $line->( $y_col, @kept );
			}
			$plot->{key_order} = $plot->{key_order} // [@y];
			# One line needs no legend: the y axis already says what it is.
			$plot->{show_legend} = $plot->{show_legend} // 0 if scalar @y == 1;
		}
		$label_axis->( 'xlabel', $x );
		$label_axis->( 'ylabel', defined $by || scalar @y == 1 ? $y[0] : undef );
	} else {
		die "plot_type \"$type\" is in %frame_roles but frame_to_data has no branch for it";
	}
	delete @{$plot}{@frame_keys};
	$plot->{data} = \%data;
}
sub frames_to_data {
	# frame_to_data for every plot hash plt will draw: the top level, each
	# subplot, and each "add" graph, which takes its subplot's plot_type when
	# it has none of its own.
	my ( $args, $sub ) = @_;
	my $graphs = sub {
		my ( $plot, $at ) = @_;
		return unless ref $plot->{add} eq 'ARRAY';
		foreach my $graph ( @{ $plot->{add} } ) {
			next unless ref $graph eq 'HASH';
			frame_to_data( $graph, $graph->{plot_type} // $plot->{plot_type}, " for an \"add\" graph$at", $sub );
		}
	};
	if ( ref $args->{plots} eq 'ARRAY' ) {
		my @top = grep { exists $args->{$_} } @frame_keys;
		if ( scalar @top ) {
			die "$sub: " . join( ', ', map { "\"$_\"" } @top ) . ' belong' . ( scalar @top == 1 ? 's' : '' )
			 . ' to a subplot when "plots" or "p" is given, not to the figure';
		}
		foreach my $j ( 0 .. $#{ $args->{plots} } ) {
			my $plot = $args->{plots}[$j];
			next unless ref $plot eq 'HASH';
			frame_to_data( $plot, $plot->{plot_type}, " at subplot $j", $sub );
			$graphs->( $plot, " at subplot $j" );
		}
	} else {
		frame_to_data( $args, $args->{plot_type}, '', $sub );
		$graphs->( $args, '' );
	}
}
sub shared_table_range {
	# One color scale for the colored_tables that share a colorbar, as
	# "cb_min" and "cb_max" for each that does not give its own.
	#
	# A table colors its cells in Perl's order of things, from the range of its
	# own cells, so tables sharing a colorbar each spread their own range over
	# the whole colormap, and the one colorbar -- drawn from the last of them --
	# was true only of that one. shared_color_scale cannot reach them, because
	# their colors are fixed when the table is drawn.
	my ( $args, $current_sub ) = @_;
	my @tables = grep { ( $args->{plots}[$_]{plot_type} // '' ) eq 'colored_table' } @{ $args->{shared_colorbar} };
	return if scalar @tables < 2;
	my ( @values, $log );
	foreach my $plot ( map { $args->{plots}[$_] } @tables ) {
		$log = 1 if bool_option( $plot->{cb_logscale}, 'cb_logscale', $current_sub );
		next unless ref $plot->{data} eq 'HASH';
		# The cells the table draws, not every cell of "data": a cell that
		# "col_labels" left out stretched the shared scale, and
		# "default_undefined" was counted in whether or not any cell was
		# undefined.
		my ( $row_keys, $cols, $cells ) = table_cells( $plot, $current_sub );
		foreach my $k1 ( @{$row_keys} ) {
			push @values, finite_values( map { $cells->{$k1}{$_} // $plot->{default_undefined} } @{$cols} );
		}
	}
	@values = grep { $_ > 0 } @values if $log;    # a log scale starts above 0, as colored_table_helper's does
	return if scalar @values == 0;                 # each table refuses an empty one by name
	my ( $lo, $hi ) = ( min(@values), max(@values) );
	foreach my $plot ( map { $args->{plots}[$_] } @tables ) {
		$plot->{cb_min} = $plot->{cb_min} // $lo;
		$plot->{cb_max} = $plot->{cb_max} // $hi;
	}
}
sub shared_color_scale {
	# Python giving every color-mapped artist of the subplots that share a
	# colorbar one scale: the lowest bottom and the highest top of any of
	# them.
	#
	# Each subplot scaled its colors to its own data -- hexbin and hist2d to
	# their own counts, which only matplotlib knows -- so the same color meant
	# a different value in each, and the one colorbar, drawn from the last of
	# them, was true only of that one. set_clim on each brings them to one
	# scale, and the colorbar follows the artist it was drawn from. The margins
	# a hexbin draws with "marginals" are left alone, being densities of their
	# own. colored_table is left to shared_table_range.
	my ( $fh, $args ) = @_;
	my @axes = map { "ax$_" } grep { ( $args->{plots}[$_]{plot_type} // '' ) ne 'colored_table' } @{ $args->{shared_colorbar} };
	return if scalar @axes < 2;
	say $fh 'shared_mappables = [m for a in [' . join( ', ', @axes ) . '] for m in a.collections + a.images if m.get_array() is not None]';
	say $fh 'shared_margins = [id(b) for m in shared_mappables for b in (getattr(m, "hbar", None), getattr(m, "vbar", None)) if b is not None]';
	say $fh 'shared_mappables = [m for m in shared_mappables if id(m) not in shared_margins and m.norm.vmin is not None and m.norm.vmax is not None]';
	say $fh 'if len(shared_mappables) > 1:';
	say $fh "\tshared_lo = min(m.norm.vmin for m in shared_mappables)";
	say $fh "\tshared_hi = max(m.norm.vmax for m in shared_mappables)";
	say $fh "\tfor m in shared_mappables:";
	say $fh "\t\tm.set_clim(shared_lo, shared_hi)";
}
sub check_add {
	# Die unless an "add" option, where given, is an array of hashes, one per
	# graph. A string in it died as 'Can't use string ("1") as a HASH ref'.
	my ( $add, $where ) = @_;
	return unless defined $add;
	if ( ref $add ne 'ARRAY' ) {
		die "\"add\"$where must be an array (of anonymous hashes), but you entered " . ( ref $add ? 'a ' . ref($add) . ' reference' : "\"$add\"" );
	}
	my @not_hash = grep { ref $add->[$_] ne 'HASH' } 0 .. $#{$add};
	if ( scalar @not_hash > 0 ) {
		die "\"add\"$where holds one HASH reference per graph, but index " . join( ', ', @not_hash ) . ' is not one';
	}
}
# The shape of "data" each plot_type reads. plot, scatter, imshow,
# venn_proportional_area and wide are not here: each checks its own.
my %data_shape = (
	bar           => 'hash',      barh       => 'hash',
	colored_table => 'hash',      pie        => 'hash',
	hexbin        => 'hash of arrays', hist2d => 'hash of arrays',
	boxplot       => 'sets',      hist       => 'sets',    # sets = an array of values, or a hash of them
	violin        => 'sets',      violinplot => 'sets',
);
sub check_data_shape {
	# Die naming the plot unless its "data" has the shape its plot_type reads.
	#
	# The helpers of these types dereferenced "data" without looking, so an
	# array given to bar died as "Not a HASH reference" and a hash of numbers
	# given to boxplot as 'Can't use string ("1") as an ARRAY ref', neither
	# naming "data" or the plot. An "add" graph was not checked at all: with
	# "data => {}" a violin wrote violinplot([]) and the script died in
	# matplotlib as "IndexError: too many indices for array".
	my ( $plot, $type, $where, $sub ) = @_;
	my $shape = $data_shape{ $type // '' };
	return unless defined $shape;
	my $data = $plot->{data};
	die "$sub: \"data\"$where is not defined" unless defined $data;
	my $ref = ref $data;
	if ( ( $ref eq 'ARRAY' ) && ( $shape eq 'sets' ) ) {
		die "$sub: \"data\"$where is an empty array" if scalar @{$data} == 0;
		return;
	}
	if ( $ref ne 'HASH' ) {
		my $wanted = ( $shape eq 'sets' ) ? 'an array of values, or a hash of them,' : "a $shape";
		die "$sub: \"data\"$where must be $wanted for $type, not " . ( $ref ? ( $ref eq 'ARRAY' ? 'an' : 'a' ) . " $ref reference" : "\"$data\"" );
	}
	die "$sub: \"data\"$where is an empty hash" if scalar keys %{$data} == 0;
	return if $shape eq 'hash';
	my @not_array = grep { ref $data->{$_} ne 'ARRAY' } sort keys %{$data};
	if ( scalar @not_array > 0 ) {
		die "$sub: each key of \"data\"$where is an array of values for $type, but "
		 . join( ', ', map { "\"$_\"" } @not_array ) . ( scalar @not_array == 1 ? ' is' : ' are' ) . ' not';
	}
}
# The pyplot functions that act on the whole figure rather than on the current
# axes, and so mean the same at the top of a figure of several subplots as
# anywhere. Every other one -- "title", "xscale", "ylim", "legend" -- acts on
# whichever axes is current, which there is the last subplot drawn.
my %figure_pyplot = map { $_ => 1 } qw(draw figimage figlegend figtext pause savefig set_loglevel show subplots_adjust suptitle tight_layout);
sub refuse_figure_keywords {
	# Die naming each keyword at the top of a figure of several subplots that
	# would not reach the subplots it seems to be about.
	#
	# The top level was checked against every plot type's options, then only
	# the figure's ("fig.") methods, pyplot's and a few of plt's own were
	# written. A "color", "cmap", "set_xlabel" or "add" there was accepted and
	# dropped; a pyplot "title" or "xscale" was written as plt.title(),
	# landing on the last subplot and replacing that subplot's own title.
	my ( $args, $current_sub ) = @_;
	my %plot_arg = map { $_ => 1 } ( 'add', 'cmap', 'plot', 'twinx' );
	my %plt_method = map { $_ => 1 } @plt_methods;
	my %fig_method = map { $_ => 1 } @fig_methods;
	my @lines;
	foreach my $key ( sort keys %{$args} ) {
		next if $fig_method{$key} || $figure_pyplot{$key};
		next if grep { $_ eq $key } ( 'sharex', 'sharey', @plt_arg );
		next if ( $key eq 'cbpad' ) && ( defined $args->{shared_colorbar} );
		if ( $plt_method{$key} ) {
			push @lines, "\"$key\" acts on one subplot, and here it would act on the last one drawn: give it in the hash of the subplot it belongs to"
			 . ( $key =~ m/^(?:title|xlabel|ylabel|legend)$/ ? ' ("suptitle", "supxlabel", "supylabel" and "figlegend" act on the whole figure)' : '' );
		} elsif ( $key eq 'cbpad' ) {
			push @lines, '"cbpad" at the top of a figure only places a "shared_colorbar"; without one, give it in the hash of the subplot whose colorbar it places';
		} elsif ( ( grep { $_ eq $key } @ax_methods, @all_opt ) || $plot_arg{$key} ) {
			push @lines, "\"$key\" belongs to one subplot: give it in the hash of the subplot it belongs to";
		}
	}
	return if scalar @lines == 0;
	die "$current_sub: with \"plots\" or \"p\", these keywords at the top of the figure would not be drawn where they seem to belong: " . join( '; ', @lines );
}
sub plt {
	my $current_sub = ( split( /::/, ( caller(0) )[3] ) )[-1]
	; # https://stackoverflow.com/questions/2559792/how-can-i-get-the-name-of-the-current-subroutine-in-perl
	# Accept BOTH calling conventions:
	#   new style:       plt( key => value, ... )
	#   back-compatible: plt({ key => value, ... })
	my $args;
	if ( ( scalar @_ == 1 ) && ( ref $_[0] eq 'HASH' ) ) {
		$args = $_[0];      # plt({ ... })
	} elsif ( ( scalar @_ % 2 ) == 0 ) {
		$args = { @_ };     # plt( ... )
	} else {
		die "$current_sub: odd number of arguments; call as $current_sub( key => value, ... ) or $current_sub({ key => value, ... })";
	}
	$args = copy_plot_hashes($args);
	%twin_axes = ();    # see its declaration
	refuse_dotted_keywords( $args, $current_sub );
	# Checked before anything multiplies them or compares them with a count of
	# plots: "ncols => 'two'" died as "Argument \"two\" isn't numeric in
	# multiplication", from a check further down that came too late to run.
	my @bad_grid = grep { ( defined $args->{$_} ) && ( ( ref $args->{$_} ) || ( $args->{$_} !~ m/^\s*\d+\s*$/ ) || ( $args->{$_} == 0 ) ) } ('ncol', 'ncols', 'nrow', 'nrows');
	if ( scalar @bad_grid > 0 ) {
		die "$current_sub: " . join( ', ', map { "\"$_\" = \"$args->{$_}\"" } @bad_grid ) . ' must be a whole number of at least 1';
	}
	# As numbers: they are written into plt.subplots() as they stand, and
	# "ncols => '02'" passed the check above and was a SyntaxError there.
	$args->{$_} = 0 + $args->{$_} foreach grep { defined $args->{$_} } ( 'ncol', 'ncols', 'nrow', 'nrows' );
	# fold the "p" interface into the engine's internal plot model
	normalise_p( $args, $current_sub ) if defined $args->{p};
	# and every "df" into the "data" of its plot_type, before anything checks
	# "data" or the keywords
	frames_to_data( $args, $current_sub );
	# Read as a Python bool, as every other switch is: tested for Perl truth,
	# "show => 'False'" wrote plt.show() and let the figure go without an
	# "output_file".
	$args->{show} = bool_option( $args->{show}, 'show', $current_sub ) if defined $args->{show};
	# "output_file" is any name at all, so it is tested for being given rather
	# than for Perl truth, which refused a file called "0" as missing.
	if ( ( not ( ( defined $args->{output_file} ) && ( length $args->{output_file} ) ) ) && ( not $args->{show} ) ) {
		p $args;
		die 'either "show" or "output_file" must be defined';
	}
	my @reqd_args = $args->{show} ? () : ('output_file'); # e.g. "my_image.svg"; optional if "show" is set
	my $single_example = 'plt({
	\'output_file\' => \'/tmp/gospel.word.counts.svg\',
	\'plot_type\'       => \'bar\',
	data              => {
	\'Matthew\' => 18345,
	\'Mark\'    => 11304,
	\'Luke\'    => 19482,
	\'John\'    => 15635,
	}
	});';
	my $multi_example = 'plt({
	\'output_file\'	=> \'svg/pie.svg\',
	plots             => [
	{
		data	=> {
		 Russian => 106_000_000,  # Primarily European Russia
		 German => 95_000_000,    # Germany, Austria, Switzerland, etc.
		},
		\'plot_type\'	=> \'pie\',
		title       => \'Top Languages in Europe\',
		suptitle    => \'Pie in subplots\',
	},
	{
		data	=> {
		 Russian => 106_000_000,  # Primarily European Russia
		 German => 95_000_000,    # Germany, Austria, Switzerland, etc.
		},
		\'plot_type\'	=> \'pie\',
		title       => \'Top Languages in Europe\',
	},
	ncols    => 3,
	});';
	my @undef_args = grep { !defined $args->{$_} } @reqd_args;
	if ( scalar @undef_args > 0 ) {
	  p @undef_args;
	  die 'the above args are necessary, but were not defined.';
	}
	if (   ( not defined $args->{plot_type} )
	  && ( not defined $args->{plots} ) )
	{
		p $args;
		die 'either "plot_type" or "plots" must be defined, but neither were';
	}
	if (ref $args->{output_file} ne '') {
		p $args;
		die '"output_file" must be a SCALAR or string, but was given a ' . ref $args->{output_file};
	}
	# A single plot is validated against the keywords of the type it asked
	# for, so that a mistyped keyword is reported against "bar"'s keywords
	# rather than the union of every type's -- which would suggest "notch"
	# to someone drawing a bar chart. This rejects nothing new: the helper
	# this plot dispatches to checks the same hash against the same list.
	# "plots" and "p" carry one type per subplot and none here, so for those
	# the union stands and each subplot is checked by its own helper.
	my $type_opt;
	if ( not defined $args->{plots} ) {
		check_plot_type({ type => $args->{plot_type} }) if defined $args->{plot_type};
		$type_opt = $opt_key_of_type{ $args->{plot_type} // '' };
	}
	my @defined_args = (@reqd_args, @ax_methods, @fig_methods, @plt_methods, @arg, @plt_arg,
	 defined $type_opt ? @{ $opt{$type_opt} } : @all_opt);
	my @bad_args = grep {
	  my $key = $_;
	  not grep { $_ eq $key } @defined_args
	} keys %{$args};
	if ( scalar @bad_args > 0 ) {
		bad_keyword_error({
			bad       => \@bad_args,
			accepted  => \@defined_args,
			preferred => defined $type_opt ? $opt{$type_opt} : \@all_opt,
			type      => defined $type_opt ? $args->{plot_type} : undef,
			sub       => $current_sub
		});
	}
	$args->{nrows} = $args->{nrow} if defined $args->{nrow}; # allow synonyms
	$args->{ncols} = $args->{ncol} if defined $args->{ncol}; # allow synonyms
	$args->{nrows} = $args->{nrows} // 1;
	$args->{ncols} = $args->{ncols} // 1;
	my $single_plot = 0; # false
	if ( ( defined $args->{plot_type} ) && ( defined $args->{data} ) ) {
	  $single_plot = 1; # true
	}
	# A single plot and "plots" both given, or half of a single plot beside
	# "plots". The single plot was drawn on ax0 and then the first subplot drawn
	# on top of it, and with two subplots the script named an "ax1" that
	# plt.subplots(1,1) had not made; half of one was ignored.
	if ( defined $args->{plots} ) {
		my @single = grep { defined $args->{$_} } ( 'plot_type', 'data' );
		if ( scalar @single > 0 ) {
			die "$current_sub: " . join( ' and ', map { "\"$_\"" } @single ) . ' belong' . ( scalar @single == 1 ? 's' : '' )
			 . ' to a single plot, and cannot be given with "plots": put ' . ( scalar @single == 1 ? 'it' : 'them' ) . ' in the hash of a subplot';
		}
		refuse_figure_keywords( $args, $current_sub );
	}
	if (($single_plot == 1) && (not defined $args->{plot_type})) {
	  p $args;
	  say STDERR $single_example;
	  die "\"plot_type\" was not defined for a single plot in $current_sub";
	}
	if ( ( $single_plot == 0 ) && (not defined $args->{plots} )) {
		say STDERR $multi_example;
		die "$current_sub: single plots need \"data\" and \"plot_type\", see example above";
	}
	if ( ( $single_plot == 0 ) && ( ref $args->{plots} ne 'ARRAY' ) ) {
		p $args;
		die "$current_sub \"plots\" must have an array entered into it";
	}
	if ( ( $single_plot == 0 ) && ( scalar @{ $args->{plots} } == 0 ) ) {
		p $args;
		die "$current_sub \"plots\" has 0 plots entered.";
	}
	# Each subplot is read as a hash from here on, so anything else died as
	# "Not a HASH reference" at whichever line first looked inside it.
	if ( $single_plot == 0 ) {
		my @not_hash = grep { ref $args->{plots}[$_] ne 'HASH' } 0 .. $#{ $args->{plots} };
		if ( scalar @not_hash > 0 ) {
			die "$current_sub: \"plots\" holds one HASH reference per subplot, but index " . join( ', ', @not_hash ) . ' is not one';
		}
	}
	if ($single_plot == 1) {
		foreach my $arg (grep {defined $args->{$_} && $args->{$_} > 1} ('ncols', 'nrows')) {
			warn "\"$arg\" is set to >1, but there is only 1 plot: resetting $arg to 1.";
			$args->{$arg} = 1;
		}
		# Sharing an axis needs a second subplot to share it with. These are
		# axes methods too, so a single plot wrote "ax0.sharex(1)", which
		# matplotlib refused: "'other' must be an instance of ... _AxesBase".
		foreach my $arg ( grep { defined $args->{$_} } ( 'sharex', 'sharey' ) ) {
			warn "\"$arg\" shares an axis between subplots, but there is only 1 plot: ignoring it.";
			delete $args->{$arg};
		}
	}
	if (   ( $single_plot == 0 )
	  && ( ( $args->{nrows} * $args->{ncols} ) < scalar @{ $args->{plots} } )
	)
	{
	  p $args;
	  my $n_plots = scalar @{ $args->{plots} };
	  say STDERR
	"ncols = $args->{ncols}; nrows = $args->{nrows}, but there are $n_plots plots.\n";
	  die 'There are not enough subplots for the data';
	}
	if ($single_plot == 0) { # multiple plots
		my $max_i = scalar @{ $args->{plots} } - 1;
		my @hash_ref_i = grep { ref $args->{plots}[$_]{data} eq 'HASH' } 0..$max_i;
		@bad_args = grep { scalar keys %{ $args->{plots}[$_]{data} } == 0} @hash_ref_i;
		if (scalar @bad_args > 0) {
			foreach my $i (@bad_args) {
				say STDERR "plot index $i:";
				p $args->{plots}[$i];
			}
			die "the above hash ref indices have empty data hashes for $current_sub";
		}
		my @output_file = grep {defined $args->{plots}[$_]{output_file}} 0..$max_i;
		if (scalar @output_file > 0) {
			p $args;
			p @output_file;
			die '"output_file" was defined at subplots indices above, which does not make sense';
		}
	}
	if (($single_plot == 1) && (ref $args->{data} eq 'HASH') && (scalar keys %{ $args->{data}} == 0 )) {
		p $args;
		die '"data" is an empty hash';
	}
	@bad_args = grep {defined $args->{$_} && (not looks_like_number($args->{$_}))} ('cbpad', 'scale', 'scalex', 'scaley');
	if (scalar @bad_args > 0) {
		p $args;
		p @bad_args;
		die 'the above args must be numeric';
	}
	# A figure infinitely large, or NaN wide, cannot be drawn; each was written
	# into the script as given, as a bare "inf" or "nan".
	foreach my $scale ( grep { defined $args->{$_} } ( 'scale', 'scalex', 'scaley' ) ) {
		die "\"$scale\" must be a finite number above 0, not \"$args->{$scale}\"" unless ( is_finite( $args->{$scale} ) ) && ( $args->{$scale} > 0 );
	}
	my @ax = map { "ax$_" } 0 .. $args->{nrows} * $args->{ncols} - 1;
	my ( @py, @y, $fh);
	my $i = 0;
	foreach my $ax (@ax) {
		my $a1i = int $i / $args->{ncols}; # 1st index
		my $a2i = $i % $args->{ncols};     # 2nd index
		$y[$a1i][$a2i] = $ax;
		$i++;
	}
	foreach my $y (@y) {
		push @py, '(' . join( ',', @{$y} ) . ')';
	}
	if ((defined $args->{shared_colorbar}) && ($single_plot == 1)) {
		warn 'There is only 1 plot/subplot, shared colorbars make no sense... deleting';
		delete $args->{shared_colorbar};
	}
	if (defined $args->{shared_colorbar}) {
		my $ref = ref $args->{shared_colorbar};
		if ($ref ne 'ARRAY') {
			p $args;
			die '"shared_colorbar" must be an array reference';
		}
		if ( scalar @{ $args->{shared_colorbar} } == 0 ) {
			die '"shared_colorbar" is an empty array: it takes the 0-based indices of the subplots that share the colorbar, e.g. [0,1]';
		}
		my @bad_idx = grep { ( not defined $_ ) || ( $_ !~ m/^\d+$/ ) } @{ $args->{shared_colorbar} };
		if ( scalar @bad_idx > 0 ) {
			p @bad_idx;
			die 'the above "shared_colorbar" entries are not 0-based subplot indices';
		}
		# Against the plots, not the cells of the grid: an index naming an empty
		# cell passed, the subplots before it had their colorbars turned off, and
		# the one meant to draw the shared colorbar did not exist, so none was
		# drawn and nothing was said.
		my $max_subplot_idx = max(@{ $args->{shared_colorbar} });
		my $max_plot_idx    = scalar @{ $args->{plots} } - 1;
		if ($max_subplot_idx > $max_plot_idx) {
			p $args;
			die "the max \"shared_colorbar\" index $max_subplot_idx > than the max index of plots, $max_plot_idx";
		}
		# plt tells each of these subplots whether to draw the colorbar, so each
		# has to be of a type that draws one. Any other died, from its own helper,
		# about a "colorbar_on" or "cbpad" the caller had never passed.
		my %draws_colorbar = map { $_ => 1 } qw(colored_table hexbin hist2d imshow scatter);
		my @no_colorbar = grep {
			( ref $args->{plots}[$_] eq 'HASH' ) && ( not $draws_colorbar{ $args->{plots}[$_]{plot_type} // '' } )
		} @{ $args->{shared_colorbar} };
		if ( scalar @no_colorbar > 0 ) {
			die '"shared_colorbar" lists subplot ' . join( ', ', map { "$_ (\"" . ( $args->{plots}[$_]{plot_type} // 'undef' ) . '")' } @no_colorbar )
			 . ', but only these plot types draw a colorbar: ' . join( ', ', sort keys %draws_colorbar );
		}
		shared_table_range( $args, $current_sub );
	}
	check_add( $args->{add}, '' );
	if ( $single_plot == 0 ) {
		check_add( $args->{plots}[$_]{add}, " at subplot $_" ) foreach 0 .. $#{ $args->{plots} };
	}
	# Before the figure is written, as the types are checked: every plot and
	# every "add" graph, which takes its plot's type when it has none.
	my @drawn = ( $single_plot == 1 ) ? ( [ $args, '' ] ) : map { [ $args->{plots}[$_], " at subplot $_" ] } 0 .. $#{ $args->{plots} };
	foreach my $drawn (@drawn) {
		my ( $plot, $at ) = @{$drawn};
		check_data_shape( $plot, $plot->{plot_type}, $at, $current_sub ) if defined $plot->{data};    # a plot with no "data" is refused by name where it is drawn
		foreach my $graph ( @{ $plot->{add} // [] } ) {
			check_data_shape( $graph, $graph->{plot_type} // $plot->{plot_type}, " for an \"add\" graph$at", $current_sub );
		}
	}
	if ( defined $args->{fh} ) {
		my $ref = ref $args->{fh};
		if ($ref ne 'File::Temp') {
			p $args;
			die "$current_sub received a \"$ref\" for \"fh\", which isn't a \"File::Temp\" object.";
		}
		$fh = $args->{fh};# open $fh, '>>', $args->{fh};
	} else {
		# File::Spec->tmpdir(), not a literal "/tmp": on MSWin32 there is no
		# /tmp, and File::Temp dies with "Parent directory (\tmp\) does not
		# exist" (CPAN Testers FAIL for 0.312 on Strawberry perl 5.42.2).
		$fh = File::Temp->new(DIR => File::Spec->tmpdir, SUFFIX => '.py', UNLINK => 0);
	}
	# Non-ASCII key names (e.g. Greek letters like ρ, τ) arrive as wide
	# characters when the caller has "use utf8", so give the output filehandle
	# a UTF-8 encoding layer. Without it, "say $fh" dies with
	# "Wide character in say" under this module's "warnings FATAL => 'all'".
	# Only add the layer if it isn't already present, to avoid double-encoding
	# a filehandle that was passed in.
	unless ( grep { /utf-?8/i } PerlIO::get_layers($fh) ) {
		# Checked by hand because this module does not "use autodie" (see
		# CLAUDE.md): binmode reports failure by returning undef, and an
		# unchecked failure here would stay silent until the first wide
		# character reached the file and died as "Wide character in say".
		# The message is autodie's own, which read
		# "Can't binmode($fh, ':encoding(UTF-8)'): Bad file descriptor".
		binmode( $fh, ':encoding(UTF-8)' )
		 or die "Can't binmode(" . $fh->filename . ", ':encoding(UTF-8)'): $!";
	}
	say 'temp file is ' . $fh->filename;
	say $fh 'import matplotlib.pyplot as plt';
	say $fh 'import json, base64';
	if ( $single_plot == 0 ) {
		# matplotlib takes a bool or one of the words "row", "col", "all" and
		# "none". A word was written bare, so "sharey => 'row'" left
		# "sharey = row" in the script and died as a NameError.
		foreach my $share ('sharex', 'sharey') {
			my $value = $args->{$share} // 0;
			if ( ( ref $value eq '' ) && ( $value =~ m/^(?:row|col|all|none)$/ ) ) {
				$args->{$share} = py_str($value);
			} elsif ( ( ref $value eq '' ) && looks_like_number($value) ) {
				$args->{$share} = py_num($value);    # matplotlib reads a number as a bool
			} else {
				$args->{$share} = bool_option( $value, $share, $current_sub ) ? 'True' : 'False';
			}
		}
		say $fh 'fig, ('
		 . join( ',', @py )
		 . ") = plt.subplots($args->{nrows}, $args->{ncols}, sharex = $args->{sharex}, sharey = $args->{sharey}, layout = 'constrained') #" . __LINE__;
	} elsif ( $single_plot == 1 ) {
		say $fh 'fig, ax0 = plt.subplots(1,1, layout = "constrained")';
	} else {
		die "\$single_plot = $single_plot breaks pigeonholes";
	}
	if ( defined $args->{plots} ) {
		my @undef_plot_types;
		my $j = 0;
		foreach my $plot (@{ $args->{plots} }) {
			push @undef_plot_types, $j unless defined $plot->{plot_type};
			$j++;	# every subplot, not only the ones missing a type: $j is the index reported
		}
		if ( scalar @undef_plot_types > 0 ) {
			p $args;
			p @undef_plot_types;
			die 'The above subplot indices are missing "plot_type"';
		}
		# Each subplot's type is checked here, before the figure is written,
		# rather than at the dispatch below: a bad type at the last subplot
		# would otherwise be found only after every earlier subplot had been
		# written to the script.
		$j = 0;
		foreach my $plot (@{ $args->{plots} }) {
			check_plot_type({ type => $plot->{plot_type}, where => "at subplot $j" });
			foreach my $graph (@{ $plot->{add} }) {
				next unless defined $graph->{plot_type};	# an "add" graph without one inherits the subplot's
				check_plot_type({ type => $graph->{plot_type}, where => "for an \"add\" graph at subplot $j" });
			}
			$j++;
		}
	}
	my %dispatch = (
		bar          => \&barplot_helper, barh         => \&barplot_helper,
		boxplot      => \&boxplot_helper, colored_table=> \&colored_table_helper,
		hexbin       => \&hexbin_helper,  hist         => \&hist_helper,
		hist2d       => \&hist2d_helper,  imshow       => \&imshow_helper,
		pie          => \&pie_helper,	    plot         => \&plot_helper,
		scatter      => \&scatter_helper, violin   => \&violin_helper,
		venn_proportional_area => \&venn_proportional_area_helper,
		violinplot   => \&violin_helper,
		wide         => \&wide_helper
	);
	if ($single_plot == 1) {
		my $has_hist = has_hist( $args, $args->{plot_type} );
		hist_range_report( $fh, 0, 'start' ) if $has_hist;
		foreach my $graph (@{ $args->{add} }) {
			$graph->{plot_type} = $graph->{plot_type} // $args->{plot_type};
			my $type = $graph->{plot_type};
			die 'plot_type not defined for "add" graph' unless defined $type;
			check_plot_type({ type => $type, where => 'for an "add" graph' });
			$dispatch{$type}->({
				fh   => $fh,
				ax   => 0,
				plot => $graph
			});
		}
		delete $args->{add};
		my $type = $args->{plot_type};
		# check_plot_type above has already refused anything outside
		# %opt_key_of_type, which lists the same 15 types as %dispatch, so this
		# fires only if the two are edited out of step.
		die "no helper is registered for plot_type \"$type\"" unless defined $dispatch{$type};
		$dispatch{$type}->({
			fh   => $fh,
			ax   => 0,
			plot => $args
		});
		hist_range_report( $fh, 0, 'report' ) if $has_hist;
		# "xlim" is not here, though it was: no keyword list accepts it, so it
		# is refused long before this as an option that isn't defined (the
		# documentation uses that refusal as its worked example), and the
		# rename could never fire.
		my %rename = (
			xlabel => 'set_xlabel',
			title  => 'set_title',
			ylabel => 'set_ylabel',
			legend => 'legend',
		);
		foreach my $opt ( grep { defined $rename{$_} } keys %{$args} ) {
			$args->{ $rename{$opt} } = delete $args->{$opt};
		}
		# emit_plt_fig => 0: the "fig." and "plt." methods in this same hash
		# are written by the two loops below, which quote through print_type.
		# Letting both passes run emitted every one of them twice.
		plot_args({
			fh           => $fh,
			args         => $args,
			ax           => 'ax0',
			emit_plt_fig => 0
		});
	}
	my $ax = 0;
	foreach my $plot (@{ $args->{plots} } ) {
		if (
				(defined $args->{shared_colorbar})               && # shared_colorbar is defined
				(grep {$_ == $ax} @{ $args->{shared_colorbar} })    # subplot's colorbar is shared w other plots
			) {
			if ($ax == max( @{ $args->{shared_colorbar} } )) { # this is the max
				$plot->{colorbar_on}     = 1; # turn on if this is the max plot
				$plot->{shared_colorbar} = $args->{shared_colorbar};
				$plot->{cbpad} = $args->{cbpad} if defined $args->{cbpad};    # not undef: an undef key is still a key, and was refused as an option
			} else {
				$plot->{colorbar_on} = 0; # turn off, its colorbar will be shared later
			}
		}
		my $has_hist = has_hist( $plot, $plot->{plot_type} );
		hist_range_report( $fh, $ax, 'start' ) if $has_hist;
		foreach my $graph (@{ $plot->{add} }) {
			$graph->{plot_type} = $graph->{plot_type} // $plot->{plot_type};
			my $type = $graph->{plot_type};
			die "plot_type not defined for \"add\" graph at ax = $ax" unless defined $type;
			# "at subplot $ax", not "at ax = $ax": the up-front check above
			# words it that way, and this line and that one describe the same
			# graph.
			check_plot_type({ type => $type, where => "for an \"add\" graph at subplot $ax" });
			$dispatch{$type}->({
				fh   => $fh,
				ax   => $ax,
				plot => $graph
			});
		}
		my @reqd_keys = (
			'data',      # data type, of which several are available
			'plot_type', # "bar", "barh", "hist", etc.
		);
		my @undef_keys = grep { !defined $plot->{$_} } @reqd_keys;
		if ( scalar @undef_keys > 0 ) {
			p $plot;
			p @undef_keys;
			die "Above args are necessary, but were not defined for plot $ax.";
		}
		# As above: the type was checked before the figure was written, so this
		# is a guard on %dispatch alone. Without it an unknown type died as
		# "Can't use an undefined value as a subroutine reference".
		die "no helper is registered for plot_type \"$plot->{plot_type}\" at ax = $ax"
		 unless defined $dispatch{ $plot->{plot_type} };
		$dispatch{$plot->{plot_type}}->({
			fh   => $fh,
			ax   => $ax,
			plot => $plot
		});
		hist_range_report( $fh, $ax, 'report' ) if $has_hist;
		my %rename = (
			xlabel => 'set_xlabel',			title  => 'set_title',
			ylabel => 'set_ylabel',			legend => 'legend',
			#			xlim => 'set_xlim',
		);
		foreach my $opt ( grep { defined $rename{$_} } keys %{$plot} ) {
			$plot->{ $rename{$opt} } = delete $plot->{$opt};
		}
		plot_args({
			fh   => $fh,
			args => $plot,
			ax   => "ax$ax"
		});
		$ax++;
	}
	shared_color_scale( $fh, $args ) if defined $args->{shared_colorbar};
	foreach my $ax (@ax) {
		say $fh "if $ax.has_data() == False:";    # remove empty plots
		say $fh "\t$ax.remove()";                 # remove empty plots
	}
	my %methods = map { $_ => 1 } @plt_methods;
	# Text is quoted as plot_args quotes it before print_type sees it. For a
	# single plot this is what always happened, though by accident: plot_args
	# quoted the caller's own hash in place, and this loop read the result.
	# plot_args now works on a copy, so the step is written out here, where it
	# now also reaches the "suptitle" of a figure of several subplots, and the
	# figure's own "supxlabel" and "supylabel", written by the fig. loop below.
	my %written_here = map { $_ => 1 } ( @plt_methods, @fig_methods );
	foreach my $text_method ( grep { ( $written_here{$_} ) && ( defined $args->{$_} ) } @text_methods ) {
		my $text = $args->{$text_method};
		$args->{$text_method} = ( ref $text eq 'ARRAY' ) ? [ map { quote_text($_) } @{$text} ] : ( ref $text ) ? $text : quote_text($text);    # an array element by element, as in plot_args
	}
	# As in plot_args: a single plot's "twinx" leaves the twin current, and its
	# "axhline" was drawn on the twin. A figure of several subplots is left
	# alone, since its own pyplot options are figure-wide ones like "suptitle".
	if ( ( $single_plot == 1 ) && ( grep { ( defined $methods{$_} ) && ( $_ ne 'show' ) } keys %{$args} ) ) {
		say $fh 'plt.sca(ax0) #' . __LINE__;
	}
	# A single plot's "legend" was written by plot_args above, and only if
	# something carries a label; writing it here too drew it a second time, and
	# warned "No artists with labels found to put in legend" when nothing did.
	foreach my $plt_method ( grep { defined $methods{$_} && ( ( $single_plot == 0 ) || ( $_ ne 'legend' ) ) } keys %{$args} ) {
		my $ref = ref $args->{$plt_method};
		if ( $ref eq '' ) {
			if ($plt_method eq 'show') {
				next; # plt.show() is emitted after plt.savefig() below
			}
			say $fh "plt.$plt_method(" . pyplot_arg( $args->{$plt_method} ) . ')#' . __LINE__;
		} elsif ( $ref eq 'ARRAY' ) {
			foreach my $j ( @{ $args->{$plt_method} } ) {
				say $fh "plt.$plt_method(" . pyplot_arg($j) . ')#' . __LINE__;
			}
		} else {
			p $args;
			die "$plt_method = \"$ref\" only accepts scalar or array types";
		}
	}
	%methods = map { $_ => 1 } @fig_methods;
	foreach my $fig_method ( grep { defined $methods{$_} } keys %{$args} ) {
		my $ref = ref $args->{$fig_method};
		if ( $ref eq '' ) {
			say $fh "fig.$fig_method($args->{$fig_method})#" . __LINE__;
		} elsif ( $ref eq 'ARRAY' ) {
			foreach my $j ( @{ $args->{$fig_method} } ) {    # say $fh "plt.$method($plt)";
				say $fh "fig.$fig_method($j)";
			}
		} else {
			p $args;
			die "$fig_method = \"$ref\" only accepts scalar or array types";
		}
	}
	if (defined $args->{scale}) {
		say $fh "fig.set_figheight(plt.rcParams['figure.figsize'][1] * $args->{scale}) #" . __LINE__;
		say $fh "fig.set_figwidth(plt.rcParams['figure.figsize'][0] * $args->{scale}) #" . __LINE__;
	}
	if (defined $args->{scalex}) {
		say $fh "fig.set_figwidth(plt.rcParams['figure.figsize'][0] * $args->{scalex}) #" . __LINE__;
	}
	if (defined $args->{scaley}) {
		say $fh "fig.set_figheight(plt.rcParams['figure.figsize'][1] * $args->{scaley}) #" . __LINE__;
	}
	if (defined $args->{output_file}) {
		write_data({
			data => $args->{output_file},
			fh   => $fh,
			name => 'output_file'
		});
		# py_str, not interpolation: on MSWin32 getcwd() and __FILE__ are
		# backslash paths, so "C:\build\..." pasted into a Python literal
		# reads "\b" as a backspace and "\c" as an invalid escape
		# (SyntaxWarning in 3.12, SyntaxError from 3.15). An apostrophe
		# anywhere in the path would close the literal early.
		my $creator = py_str( getcwd() . "/$RealScript called using \"$current_sub\" in "
		 . __FILE__ . " version $VERSION with Perl " . sprintf( '%vd', $^V ) );
		# The Python and matplotlib versions are read by the script as it
		# runs, not by Perl as it writes: with "execute => 0" the script may
		# be run later, or elsewhere, by an interpreter Perl never sees.
		say $fh 'import matplotlib, platform';
		say $fh "plt.savefig(output_file, bbox_inches = 'tight', metadata={'Creator': $creator"
		 . " + ', Python ' + platform.python_version() + ', matplotlib ' + matplotlib.__version__})";
	}
	say $fh 'plt.show()' if $args->{show}; # after savefig, so the file is written even if the window is never closed
	# As a Python bool, as the other switches are: compared with "==", "execute
	# => 'yes'" died as 'Argument "yes" isn't numeric'.
	$args->{execute} = bool_option( $args->{execute} // 1, 'execute', $current_sub );
	say $fh 'plt.close()' if $args->{execute} == 0;
	if ( $args->{execute} ) {
		my @python = python_command();
		if ( scalar @python == 0 ) {
			die 'no Python 3 interpreter was found to run ' . $fh->filename
			 . ': tried ' . join( ', ', map { '"' . join( ' ', @{$_} ) . '"' } @windows_python_candidates )
			 . '. Install Python 3 and matplotlib, set MATPLOTLIB_SIMPLE_PYTHON to the path of a Python 3 that has them, or pass "execute => 0" to write the script without running it';
		}
		my $errno;
		my ($stdout, $stderr, $exit) = capture {
			# The list form, not "python3 $file": the one-argument form goes
			# through the shell and splits on whitespace, so a temp directory
			# with a space in it -- %TEMP% on a Windows smoker sits under
			# C:\Users\<name>, and a user name with a space is ordinary --
			# would run python against a truncated path.
			# Departs from this file's "warnings FATAL => 'all'" on purpose,
			# for this statement only: with exec warnings fatal, a missing
			# interpreter dies right here as "Can't exec "python3"", system()
			# never returns, and the three failure modes below get reported
			# two different ways. autodie raised all three as one kind of
			# exception naming the command, which is what this restores.
			no warnings 'exec';
			my $status = system( @python, $fh->filename );
			# Read here, not after capture(): capture() does its own file
			# operations on the way out and they overwrite $!, which was
			# observed to leave "failed to start:" with nothing after it.
			$errno = "$!";
			$status;
		};
		if ($exit != 0) {
			say STDERR "STDOUT = $stdout";
			say STDERR "STDERR = $stderr";
			# The three ways system() reports failure, told apart because
			# they call for different fixes: no interpreter, a killed
			# process, and a python error. "use autodie" used to raise these
			# through IPC::System::Simple, but it threw from inside capture(),
			# so the two lines above -- the python traceback, the only thing
			# that says what is actually wrong -- were never reached. See
			# CLAUDE.md.
			my $why;
			if ( $exit == -1 ) {
				$why = "failed to start: $errno";
			} elsif ( $exit & 127 ) {
				$why = 'died to signal ' . ( $exit & 127 );
			} else {
				$why = 'unexpectedly returned exit value ' . ( $exit >> 8 );
			}
			die join( ' ', @python, $fh->filename ) . " $why";
		}
		# What the script printed, which capture{} above took out of the
		# terminal. The script reports things the caller has no other way to
		# learn -- the range of a hist's bin heights, a hist2d's density range,
		# both computed by matplotlib as it draws -- and those lines were
		# captured and then dropped on the floor on every successful run, so
		# only a *failing* run ever showed them. Already newline-terminated by
		# python, hence print and not say.
		print $stdout if length $stdout;
		say 'will write ' . "\e[36;103m$args->{output_file}\e[0m" if defined $args->{output_file};
	} else { # not running yet
		say 'will write ' . "\e[36;103m$args->{output_file}\e[0m" if defined $args->{output_file};
	}
	return $fh->filename;
}
sub venn_proportional_area_helper {
	my ($args) = @_;
	my $current_sub = ( split( /::/, ( caller(0) )[3] ) )[-1]
	; # https://stackoverflow.com/questions/2559792/how-can-i-get-the-name-of-the-current-subroutine-in-perl
	if ( ref $args ne 'HASH' ) {
		die "args must be given as a hash ref, e.g. \"$current_sub({ data => \@blah })\"";
	}
	my @reqd_args = (
		'ax',   # e.g. 0, 1, 2 ... the subplot index, passed in by plt
		'fh',   # the File::Temp filehandle, passed in by plt
		'plot', # the per-plot args from the caller
	);
	my @undef_args = grep { !defined $args->{$_} } @reqd_args;
	if ( scalar @undef_args > 0 ) {
		p @undef_args;
		die 'the above args are necessary, but were not defined.';
	}
	my @opt = (@ax_methods, @plt_methods, @fig_methods, @arg, 'ax', @{ $opt{$current_sub} });
	my $plot      = $args->{plot};
	my @undef_opt = grep {
		my $key = $_;
		not grep { $_ eq $key } @opt
	} keys %{$plot};
	if ( scalar @undef_opt > 0 ) {
		bad_keyword_error({
			bad       => \@undef_opt,
			accepted  => \@opt,
			preferred => $opt{$current_sub},
			type      => $plot->{plot_type},
			sub       => $current_sub
		});
	}
	# Each of these died as Perl's own error, or as a Python traceback, naming
	# no option: "Not a HASH reference" for array data, and below, "Can't use
	# string as an ARRAY ref" for a string "set_colors".
	if ( ref $plot->{data} ne 'HASH' ) {
		die "$current_sub takes a hash of sets, one array of members per set, e.g. { A => [1, 2], B => [2, 3] }, not "
		 . ( ref $plot->{data} ? 'a ' . ref( $plot->{data} ) . ' reference' : 'a scalar' );
	}
	# matplotlib_venn only draws area-proportional diagrams for 2 or 3 sets
	my $n_keys = scalar keys %{ $plot->{data} };
	if ( ( $n_keys != 2 ) && ( $n_keys != 3 ) ) {
		p $plot->{data};
		die "$current_sub only takes 2 or 3 sets of data.";
	}
	foreach my $key ( keys %{ $plot->{data} } ) {
		if ( ref $plot->{data}{$key} ne 'ARRAY' ) {
			p $plot->{data};
			die "\"$key\" must be an array reference in $current_sub";
		}
		if ( grep { !defined } @{ $plot->{data}{$key} } ) {
			p $plot->{data}{$key}, array_max => scalar @{ $plot->{data}{$key} };
			die "\"$key\" has undefined values in $current_sub, there may be undefined values in other keys";
		}
	}
	my @keys;
	if ( defined $plot->{key_order} ) {
		@keys = check_key_order({
			keys   => $plot->{key_order},
			data   => $plot->{data},
			option => 'key_order',
			sub    => $current_sub
		});
		if ( scalar @keys != $n_keys ) {
			p $plot;
			die "\"key_order\" has " . scalar(@keys) . " keys, but data has $n_keys in $current_sub";
		}
	} else {
		@keys = sort keys %{ $plot->{data} };
	}
	# The import is emitted at the point of use; a duplicate "from matplotlib_venn
	# import ..." across several subplots is harmless in Python.
	say { $args->{fh} } "from matplotlib_venn import venn$n_keys";
	my $ax = $args->{ax} // '';
	my @sets;
	foreach my $i ( 0 .. $#keys ) { # "each @array" requires perl 5.12
		my $key  = $keys[$i];
		my $name = "venn_ax${ax}_set$i";
		say { $args->{fh} } "$name = set(["
		. py_list( @{ $plot->{data}{$key} } ) . '])';
		push @sets, $name;
	}
	my $opt = '';
	if ( defined $plot->{set_colors} ) {
		# One color per set, which matplotlib_venn reads by position; a list of
		# any other length was a TypeError from inside it.
		if ( ( ref $plot->{set_colors} ne 'ARRAY' ) || ( scalar @{ $plot->{set_colors} } != $n_keys ) ) {
			die "\"set_colors\" is an array of one color per set in $current_sub, and there are $n_keys sets";
		}
		$opt .= ', set_colors=(' . py_list( @{ $plot->{set_colors} } ) . ')';
	}
	if ( defined $plot->{alpha} ) {
		check_numbers( [ $plot->{alpha} ], '"alpha"', $current_sub );    # written bare, so a word was a NameError
		$opt .= ", alpha=" . py_num( $plot->{alpha} );
	}
	say { $args->{fh} } "venn$n_keys(["
	. join( ',', @sets ) . '],('
	. py_list(@keys) . "), ax=ax$ax$opt)";
}
# Generate wrappers dynamically
my @wrappers = qw(bar barh boxplot colored_table hexbin hist hist2d imshow pie plot scatter venn_proportional_area violin violinplot wide);

foreach my $sub_name (@wrappers) {
	no strict 'refs'; # Gemini helped
	*$sub_name = sub {
		# accept both bar({ ... }) and bar( ... )
		my $args;
		if ( ( scalar @_ == 1 ) && ( ref $_[0] eq 'HASH' ) ) {
			$args = $_[0];
		} elsif ( ( scalar @_ % 2 ) == 0 ) {
			$args = { @_ };
		} else {
			die "$sub_name: odd number of arguments; call as $sub_name( key => value, ... ) or $sub_name({ key => value, ... })";
		}
		# Check for conflicts
		if ((defined $args->{plot_type}) && ($args->{plot_type} ne $sub_name)) {
			warn "$args->{plot_type} will be ignored for $sub_name";
		}
		if (defined $args->{plots}) {
			die "\"plots\" is meant for the subroutine \"plt\"; $sub_name is single-only";
		}
		if (defined $args->{p}) {
			die "\"p\" is meant for the subroutine \"plt\"; $sub_name is single-only";
		}
		# Call plt
		plt({ %{ $args }, plot_type => $sub_name });
	};
}
1;
__END__
# from md2pod.pl πατερ ημων ο εν τοις ουρανοις, ἁγιασθήτω τὸ ὄνομά σου
=encoding utf8

=head1 NAME

Matplotlib::Simple - Access Matplotlib from Perl; providing consistent user interface between different plot types

=head1 Synopsis

Take a data structure in Perl, and automatically write a Python3 script using matplotlib to generate an image.  The Python3 script is saved in the system's temporary directory (C<< File::Spec-E<gt>tmpdir >>, which is C</tmp> on unix), to be edited at the user's discretion.
Depends on Python 3 and matplotlib.  The script is run with C<python3>; on Windows, where a standard install has no C<python3>, it is run with the first of C<python>, C<py -3> and C<python3> that reports itself as Python 3 (as of version 0.315 -- before that, the module could not run its script on Windows at all).  To run a different interpreter -- a venv, or a newer Python on a cluster whose system C<python3> is too old -- set the environment variable C<MATPLOTLIB_SIMPLE_PYTHON> to its path, such as C<export MATPLOTLIB_SIMPLE_PYTHON=~/mpl/bin/python3> (as of version 0.317).  The generated scripts cannot run with a matplotlib older than 3.5, which does not accept the constrained layout they ask for; the test suite is written against 3.10 and newer, and skips its drawing checks with anything older.  Pass C<< execute =E<gt> 0 >> to write the script without running it.

My aim is to simplify the most common tasks as much as possible.  In my opinion, using this module is much easier than matplotlib itself.

=head1 Single Plots

Simplest use case:

 use Matplotlib::Simple;
 bar(
    output_file       => '/tmp/gospel.word.counts.png',
    data              => {
       Matthew => 18345,
       Mark    => 11304,
       Luke    => 19482,
       John    => 15635,
    }
 );

A more complete (and slightly faster execution):

 use Matplotlib::Simple;
 plt(
    output_file       => '/tmp/gospel.word.counts.png',
    plot_type         => 'bar',
    data              => {
       Matthew => 18345,
       Mark    => 11304,
       Luke    => 19482,
       John    => 15635,
    }
 );


=for html
<p>
<img width="651" height="491" alt="gospel word counts" src="https://github.com/user-attachments/assets/a008dece-2e34-47bf-af0f-8603709f7d52" />
<p>


=head1 Multiple Plots

Having a C<plots> argument as an array lets the module know to create subplots:

 use Matplotlib::Simple 'plt';
 plt(
     output_file     => 'svg/pies.png',
     plots             => [
     {
             data    => {
              Russian => 106_000_000,  # Primarily European Russia
              German => 95_000_000,    # Germany, Austria, Switzerland, etc.
             },
             plot_type => 'pie',
             title       => 'Top Languages in Europe',
             suptitle    => 'Pie in subplots',
         },
         {
             data    => {
              Russian => 106_000_000,  # Primarily European Russia
              German => 95_000_000,    # Germany, Austria, Switzerland, etc.
             },
             plot_type => 'pie',
             title       => 'Top Languages in Europe',
         },
     ],
     ncols    => 2,
 );

which produces the following subplots image:


=for html
<p>
<img width="651" height="424" alt="pies" src="https://github.com/user-attachments/assets/49d3e28b-f897-4b01-9e72-38afa12fa538" />
<p>


C<bar>, C<barh>, C<boxplot>, C<hexbin>, C<hist>, C<hist2d>, C<imshow>, C<pie>, C<plot>, C<scatter>, and C<violinplot> all match the methods in matplotlib itself.  C<venn_proportional_area> additionally wraps the LL<https://pypi.org/project/matplotlib-venn/> library (see L<#venn_proportional_area>).

Everything that belongs to one subplot goes in that subplot's hash.  The top of
the call takes only what belongs to the whole figure: C<output_file>, C<show>,
C<execute>, C<ncols>/C<nrows>, C<scale>/C<scalex>/C<scaley>, C<sharex>/C<sharey>,
C<shared_colorbar> (with C<cbpad> to place it), the figure's own methods such as
C<set_figwidth> and C<supxlabel>, and those of pyplot's that act on the whole
figure: C<suptitle>, C<figtext>, C<figlegend>, C<figimage>, C<subplots_adjust> and
C<tight_layout>.  Anything else there is refused, naming where it belongs: a
C<title> or an C<xscale> at the top would act on whichever subplot was drawn last,
and a C<color> or an C<add> would reach none of them.  C<plot_type> and C<data> are a
single plot, and are refused beside C<plots>.

=head2 The C<p> argument

C<p> is a single, uniform way to describe one I<or> many subplots, so you no
longer need a top-level C<plot_type> (or the older C<plots> array). Each plot is a
hash, exactly like a single-plot call, and C<p> collects the subplots into one
array.

The rule is simple: B<< one element of C<p> is one subplot. >>

=over

=item * A B<hash> element is a subplot containing a single plot.

=item * An B<array of hashes> element is a single subplot whose plots are drawn on
the B<same> axes: the first hash is the base plot and the rest are
I<additions> (overlays), exactly like C<add>.

=back

The two forms may be B<mixed freely> in the same C<p>. The first (or only) hash
of a subplot supplies that subplot's axes-level options (C<title>, C<xlabel>,
C<ylabel>, C<legend>, …).

If you don't give a grid, the subplots are laid out automatically on a
near-square grid. Give C<ncol>/C<nrow> (aliases for C<ncols>/C<nrows>) to control
it; supplying only one dimension derives the other (so C<< ncols =E<gt> 1 >> stacks the
subplots in a single column), and supplying both is honored as given.

C<p> cannot be combined with C<plot_type>, C<data>, C<plots>, or C<add>.

 > Arguments are now passed as a plain list — C<plt( ... )> — though the older
 > C<plt({ ... })> form still works.

=head3 One subplot, several plots overlaid

Wrap the plots in an inner array and they all land on a single subplot (the
first is the base plot, the rest are additions):

 plt(
     p => [
         [
             {
                 data => {
                     E => [ 55, @{$x}, 160 ],
                     B => [ @{$y}, 140 ],
                 },
                 plot_type => 'boxplot',
                 title       => 'Single Box Plot: Specified Colors',
                 colors      => { E => 'yellow', B => 'purple' },
             },
             {
                 data => {
                     A => [ 55, @{$z} ],
                     E => [ @{$y} ],
                     B => [ 122, @{$z} ],
                 },
                 plot_type => 'violinplot',
                 title       => 'Single Violin Plot: Specified Colors',
                 colors      => { E => 'yellow', B => 'purple', A => 'green' },
             },
         ],
     ],
     output_file => '1plot.svg',    # note: no C<plot_type> needed
 );

=head3 Multiple subplots

Give each subplot as its own element. A bare hash is a one-plot subplot, so two
hashes make two subplots; with C<< ncol =E<gt> 2 >> they sit side by side:

 plt(
     p => [
         {
             data => {
                 E => [ 55, @{$x}, 160 ],
                 B => [ @{$y}, 140 ],
             },
             plot_type => 'boxplot',
             title       => 'Box Plot: Specified Colors',
             colors      => { E => 'yellow', B => 'purple' },
         },
         {
             data => {
                 A => [ 55, @{$z} ],
                 E => [ @{$y} ],
                 B => [ 122, @{$z} ],
             },
             plot_type => 'violinplot',
             title       => 'Violin Plot: Specified Colors',
             colors      => { E => 'yellow', B => 'purple', A => 'green' },
         },
     ],
     ncol          => 2,
     output_file => '2plots.svg',
 );

To overlay extra plots on any one subplot, make that element an array of hashes
instead of a bare hash (the first is the plot, the rest are additions). Bare
hashes and inner arrays may be intermixed in the same C<p>, for example
C<< p =E<gt> [ \%single, [ \%base, \%overlay ], \%another ] >>.

=head2 Options

C<sharex> and C<sharey> are both implemented at the plot, rather than subplot, level.  Each takes C<True> or C<False> (or 1 or 0), or one of Matplotlib's words C<row>, C<col>, C<all> and C<none>, such as C<< sharey =E<gt> 'row' >>.  See Matplotlib's documentation for more clarity.

A number in C<data> may be NaN or infinite.  Such a value is drawn as Matplotlib draws it -- a NaN is a gap in a line, an empty cell of an C<imshow> or C<colored_table> -- and it does not count towards any range this module works out, such as a color scale.  C<boxplot> and C<violin> leave NaN out as they leave out an undefined value, and C<hist>, C<pie> and C<violin> refuse an infinite value, since there is nothing finite to bin, size or draw a density for.

=head3 Quoting text: commas and apostrophes

C<title>, C<suptitle>, C<supxlabel>, C<supylabel>, C<xlabel>, C<ylabel>,
C<set_title>, C<set_xlabel> and C<set_ylabel> are quoted for you, unless the text
is already Python of your own.
Text is taken to be Python when it holds a comma or a quote I<and> opens the way
Python does: with a string literal, which may carry a prefix such as C<r> or
C<f>, or with a keyword argument.  The literal has to close, and either be the
whole of the text or be followed by a comma, so C<"'Tis the season"> and
C<'"A" vs "B"'> are prose.  That is what makes a raw string such as

 xlabel => 'r"$\it{anno}$ $\it{domini}$"',    # italics, via mathtext

possible, along with options after the text:

 title => '"Two groups, mean and s.d.", fontsize = 20',

Anything else is prose, and is quoted, comma, apostrophe and all:

 title => 'Two groups, mean and s.d.',     # quoted for you
 title => "war's end",                     # likewise

Up to 0.318 any text holding a comma, an apostrophe or a double quote was passed
through, so prose like the two lines above had to carry its own quotes, and
without them the script was a syntax error.  Quoting it yourself still works.

Either kind of quote will do.  Up to 0.3131 a single plot wrote its figure-wide
options twice — C<suptitle> came out once for the subplot and once for the
figure — and the second pass ran its own quoting rules over text the first had
already quoted, turning C<< suptitle =E<gt> "'a, b'" >> into C<plt.suptitle(''a, b'')>, a
syntax error.  Double quotes were the documented way round it.  Each option is
now written once, and text that already carries a quote of its own is left
alone.

Every other option is passed through as written, so text inside C<legend>, C<text>
and friends is Python syntax throughout: C<< legend =E<gt> 'loc = "upper left"' >>.

The exception is an option written as a C<plt.> call, such as C<xscale>, C<ylim>
or C<axhline>, at a single plot and at a subplot alike.  A word is quoted for
you, so C<< xscale =E<gt> 'log' >> becomes C<plt.xscale('log')>.  A value that is already
Python is left as it is: a number, a list of numbers such as C<< ylim =E<gt> '0, 10' >>,
C<None>, C<True> or C<False>, one bracketed group such as C<< ylim =E<gt> '(0, 10)' >>, one
function call, a keyword argument such as C<< axhline =E<gt> 'y = 0.5' >>, or anything
holding a quote of its own.

=head3 An option that isn't defined

Each plot type has its own list of options, so an option is only ever right or
wrong I<for the plot type you asked for>.  An option that isn't on that list
dies, naming what you wrote and what it resembles:

 bar(
    output_file => 'counts.svg',
    data          => { Matthew => 18345, Mark => 11304 },
    xlim          => '0, 20000',
 );
 
 "xlim" isn't defined for plot_type "bar", perhaps you meant one of these
 defined keywords: (clim, ylim, set_xlim)

The suggestions come from the list that plot type actually accepts, so the same
misspelling gets different answers at different plot types — C<bins_> is offered
C<bins> at a C<hist> and is not offered it at a C<boxplot>, which has no C<bins>.
Separators are ignored when matching, so C<key.order> finds C<key_order>, and two
transposed characters count as one mistake, so C<widht> finds C<width>.

An option that is real but belongs elsewhere is the commonest case, and says so
rather than leaving you to wonder whether the documentation lied:

 plot( ..., notch => 'True' );
 
 "notch" isn't defined for plot_type "plot"
         "notch" is a defined keyword, but for plot_type boxplot

=head3 A C<plot_type> that isn't defined

C<plot_type> is the one argument whose I<value> comes from a fixed list, and a
misspelling in it is answered the same way:

 plt(
    output_file => 'counts.svg',
    plot_type     => 'barr',
    data          => { Matthew => 18345, Mark => 11304 },
 );
 
 "barr" isn't a defined plot_type, perhaps you meant one of these defined
 plot types: (bar, barh)

The type is checked before the options are, because an unrecognised type leaves
no per-type list to check them against.  A type given for a subplot, or for an
C<add> graph, says which one it was:

 "violn" isn't a defined plot_type at subplot 1, perhaps you meant one of
 these defined plot types: (violin)
 
 "pye" isn't a defined plot_type for an "add" graph at subplot 1, perhaps
 you meant one of these defined plot types: (pie)

=head1 Color Bars (colorbars)

Colarbar args attempt to match matplotlib closely

=for html
<table>
<tbody>
<tr><td>Option</td><td>Description</td><td>Example</td></tr>
<tr><td>--------</td><td>-------</td><td>-------</td></tr>
<tr><td><code>cbdrawedges</code></td><td>Whether to draw lines at color boundaries</td><td><code>cbdrawedges => 1</code></td></tr>
<tr><td><code>cblabel</code></td><td>The label on the colorbar's long axis</td><td><code>cblabel => 1</code></td></tr>
<tr><td><code>cblocation</code></td><td>of the colorbar None or {'left', 'right', 'top', 'bottom'}</td><td></td></tr>
<tr><td><code>cborientation</code></td><td># None or {<code>vertical</code>, <code>horizontal</code>}</td><td></td></tr>
<tr><td><code>cbpad</code></td><td>pad : float, default: 0.05 if vertical, 0.15 if horizontal; Fraction of original Axes between colorbar and new image Axes</td><td></td></tr>
<tr><td><code>cb_logscale</code></td><td>color on a log scale: <code>'True'</code> or <code>'False'</code> (in any case), or 1 or 0.  Works for <code>colored_table</code>, <code>hexbin</code>, <code>hist2d</code>, <code>imshow</code> and <code>scatter</code>, though not for an <code>imshow</code> with a <code>stringmap</code>, whose colors are categories.  The bottom of the scale is the smallest value above 0 unless <code>cb_min</code> or <code>vmin</code> says otherwise</td><td><code>cb_logscale => 1</code></td></tr>
<tr><td><code>cb_min</code>, <code>cb_max</code></td><td>the bottom and top of the color scale, taken from the data where not given.  For <code>hexbin</code>, <code>hist2d</code> and <code>imshow</code> these are the same as <code>vmin</code> and <code>vmax</code>, and only one of the two may be given for each end</td><td><code>cb_min => 0, cb_max => 10</code></td></tr>
<tr><td><code>shared_colorbar</code></td><td>share colorbar between different plots: specify plot indices.  Each subplot listed must be one that draws a colorbar: <code>colored_table</code>, <code>hexbin</code>, <code>hist2d</code>, <code>imshow</code> or <code>scatter</code>.  The subplots listed are put on one color scale, running from the lowest bottom of any of them to the highest top, so that one color means one value in all of them</td><td><code>shared_colorbar => [0,1]</code></td></tr>
</tbody>
</table>

Every switch among the options -- C<cb_logscale>, C<colorbar_on>, C<show_colorbar>,
C<show_legend>, C<show_numbers>, C<mirror>, C<stacked>, C<log>, C<notch>, C<showcaps>,
C<showfliers>, C<showmeans>, C<medians>, C<whiskers>, C<marginals>, C<density> and
C<execute> -- takes C<'True'> or C<'False'> in any case, or a number, where 0 is off.
Anything else, such as C<'yes'>, is refused by name, since it could mean either.
C<logscale> for C<bar> is the one exception, and takes Perl truth.

=head1 Size/Dimensions of output file

=for html
<table>
<tbody>
<tr><td>Option</td><td>Description</td><td>Example</td></tr>
<tr><td>--------</td><td>-------</td><td>-------</td></tr>
<tr><td><code>scale</code></td><td>scale/multiply the size of the output figure; this and the two below must be finite and above 0</td><td><code>scale => 2.4</code></td></tr>
<tr><td><code>scalex</code></td><td>scale/multiply the x-axis only</td><td><code>scalex => 2.4</code></td></tr>
<tr><td><code>scaley</code></td><td>scale/multiply the y-axis only</td><td><code>scaley => 1.4</code></td></tr>
</tbody>
</table>

=head1 Examples/Plot Types

Every plot type can be called two ways: through C<plt> with C<< 'plot_type' =E<gt> 'bar' >>,
or through the same-named helper subroutine, C<bar( ... )>, which is a thin wrapper
that fills in C<'plot_type'> and calls C<plt> for you.  Everything documented for a
plot type therefore works in either form, and works identically whether the plot
is alone or one panel of a C<plots> grid.

=head2 Which helper takes which data?

The fastest way to pick a plot type is to start from the shape of the data you
already have in Perl:

=for html
<table>
<tbody>
<tr><td><code>data</code> you have</td><td>Helpers that take it</td><td>Notes</td></tr>
<tr><td>--------</td><td>-------</td><td>-------</td></tr>
<tr><td>hash of numbers, <code>A => 1</code></td><td><code>bar</code>, <code>barh</code>, <code>pie</code></td><td>one bar/wedge per key</td></tr>
<tr><td>hash of array refs, <code>A => [1,2,3]</code></td><td><code>boxplot</code>, <code>violin</code>, <code>hist</code>, <code>hexbin</code>, <code>hist2d</code>, <code>scatter</code>, <code>venn_proportional_area</code></td><td>one distribution/series per key; <code>hexbin</code> and <code>hist2d</code> need exactly 2 keys (x and y), <code>scatter</code> 2 or 3, <code>venn_proportional_area</code> 2 or 3</td></tr>
<tr><td>hash of hashes, <code>A => { X => 1 }</code></td><td><code>bar</code>, <code>barh</code>, <code>colored_table</code></td><td>grouped/stacked bars, or a matrix</td></tr>
<tr><td>hash of <code>[ \@x, \@y ]</code> pairs</td><td><code>plot</code></td><td>one labelled line per key</td></tr>
<tr><td>hash of arrays of <code>[ \@x, \@y ]</code> pairs</td><td><code>wide</code></td><td>repeated runs of the same curve, summarised</td></tr>
<tr><td>hash of hashes of array refs</td><td><code>scatter</code></td><td>several labelled sets, each with its own x/y (and colour)</td></tr>
<tr><td>hash of hashes of numbers, <code>A => { X => 1, Y => 2 }</code></td><td><code>scatter</code></td><td>one labelled point per key</td></tr>
<tr><td>a single array ref</td><td><code>hist</code>, <code>boxplot</code>, <code>violin</code></td><td>the one-series shorthand</td></tr>
<tr><td>array of <code>[ \@x, \@y ]</code> pairs</td><td><code>plot</code>, <code>wide</code></td><td>unlabelled lines</td></tr>
<tr><td>2-D array (array of array refs)</td><td><code>imshow</code></td><td>a raster/heatmap; strings allowed via <code>stringmap</code></td></tr>
<tr><td>a data frame (<code>df</code>) in any of <code>Stats::LikeR</code>'s four shapes</td><td>every type but <code>imshow</code>, <code>venn_proportional_area</code> and <code>wide</code></td><td>name the columns with <code>x</code>, <code>y</code> and <code>by</code>; see [Plotting a data frame](#plotting-a-data-frame-with-df)</td></tr>
</tbody>
</table>

A few conventions hold across all of them:

=over

=item * Keys are used in B<sorted order> unless you say otherwise.  C<key_order> is
accepted by C<bar>, C<barh>, C<boxplot>, C<violin>, C<hexbin>, C<hist2d>, C<pie>,
C<plot> and C<venn_proportional_area>; C<scatter> spells the same idea C<keys>;
and C<colored_table> uses C<row_labels>/C<col_labels>.  C<hist> and C<wide> take no
ordering option at all, and C<imshow> has no keys to order.

=item * An ordering option naming a key that C<data> does not have is an error naming
that key.  It used to reach the writer as an undefined value and die as C<Use
of uninitialized value in join or string>, which named neither the key nor the
option it came from.

=item * C<title>, C<xlabel>, C<ylabel>, C<suptitle>, C<set_xlim>, C<legend> and the rest of
Matplotlib's C<ax>/C<fig>/C<plt> methods are accepted by every plot type; see
L<#options>.

=item * Anything that is not recognised is reported as an error listing the arguments
that I<are> accepted, rather than being silently ignored.

=back

Consider the following helper subroutines to generate data to plot:

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

=head2 Plotting a data frame with C<df>

A table read with C<Stats::LikeR>'s C<read_table>, or built by hand, can be given
whole as C<df> instead of C<data>, with the columns to draw named by role.  The
module rearranges the columns into the C<data> the plot type takes, so every
other option works as it does with C<data>:

 use Stats::LikeR 'read_table';
 my $d = read_table('main.table.csv');
 bar(
     output_file => 'bedroc.svg',
     df            => $d,
     x             => 'Method',          # one bar per row, labelled by this column
     y             => 'BEDROC(32.2)',    # and as tall as this one
 );

C<df> can be any of the four shapes C<Stats::LikeR> uses.  It is recognised by its
structure, so C<Stats::LikeR> itself is not needed:

=for html
<table>
<tbody>
<tr><td>shape</td><td>example</td><td>rows are taken</td></tr>
<tr><td>--------</td><td>-------</td><td>-------</td></tr>
<tr><td>array of hashes</td><td><code>[ { name => 'Al', age => 30 }, ... ]</code></td><td>in array order</td></tr>
<tr><td>hash of arrays</td><td><code>{ name => ['Al', ...], age => [30, ...] }</code></td><td>in array order; every column used must be the same length, except by <code>hist</code> and <code>violin</code> without <code>by</code></td></tr>
<tr><td>hash of hashes</td><td><code>{ Al => { age => 30 }, ... }</code></td><td>in the sorted order of the row names, as <code>Stats::LikeR</code>'s <code>vals</code> takes them</td></tr>
<tr><td>array of arrays</td><td><code>[ [ 'Al', 30 ], ... ]</code></td><td>in array order; columns are 0-based positions, negative from the end</td></tr>
</tbody>
</table>

The roles each plot type reads:

=for html
<table>
<tbody>
<tr><td>plot type</td><td><code>x</code></td><td><code>y</code></td><td><code>by</code></td></tr>
<tr><td>--------</td><td>-------</td><td>-------</td><td>-------</td></tr>
<tr><td><code>bar</code>, <code>barh</code></td><td>the labels; leave it out of a hash of hashes to label by row name</td><td>the heights; several columns make grouped bars</td><td>one bar per group within each label</td></tr>
<tr><td><code>pie</code></td><td>the labels, as for <code>bar</code></td><td>the sizes</td><td></td></tr>
<tr><td><code>hist</code></td><td>the values; several columns make several histograms; every column of numbers if left out</td><td></td><td>one histogram per group</td></tr>
<tr><td><code>boxplot</code></td><td></td><td>the values; several columns make several boxes</td><td>one box per group</td></tr>
<tr><td><code>violin</code></td><td></td><td>the values, as for <code>boxplot</code>; every column of numbers if left out</td><td>one violin per group</td></tr>
<tr><td><code>scatter</code></td><td>x</td><td>y</td><td>one set of points per group</td></tr>
<tr><td><code>plot</code></td><td>x</td><td>y; several columns make several lines</td><td>one line per group</td></tr>
<tr><td><code>hist2d</code>, <code>hexbin</code></td><td>x</td><td>y</td><td></td></tr>
<tr><td><code>colored_table</code></td><td>the row labels, as for <code>bar</code></td><td>the columns of the table; every column but <code>x</code> if left out</td><td></td></tr>
</tbody>
</table>

C<scatter> also reads C<color_key> as the name of a column, which colors each point
and gets a colorbar:

 scatter(
     output_file => 'people.svg',
     df            => $d,
     x             => 'height',
     y             => 'weight',
     color_key     => 'age',
     by            => 'sex',     # one marker per sex, on one shared color scale
 );

Things C<df> does for you:

=over

=item * B<x is drawn on the x axis.>  C<scatter>, C<hist2d> and C<hexbin> otherwise
assign axes by the sorted order of the keys, so C<keys> and (for C<hist2d> and
C<hexbin>) C<key_order> are refused alongside C<df>.

=item * B<The axes are labelled with the column names>, unless you give C<xlabel> or
C<ylabel>.

=item * B<Bars and wedges are in the order of the rows>, and groups made by C<by> are
in numeric order when every group is a number (2 before 10) and in string
order otherwise.  An explicit C<key_order> still wins.

=item * B<< C<plot> draws each line in the order of x >>, so a table need not be sorted
first.

=item * B<< A row with no value (an C<undef>) in a column the plot uses is left out >>,
with a warning saying how many rows were dropped and from which columns, as
ggplot2 does.  Columns of C<hist>, C<boxplot> and C<violin> are filtered
independently, so a gap in one column does not cost the others a value.
C<colored_table> keeps such cells, and draws them as undefined.  A row that is
itself C<undef>, in an array of arrays or of hashes, is a row with no values.

=item * B<A color hash keyed by group or column> works for grouped bars.

=item * B<< C<hist> and C<violin> draw every column of numbers when C<x> or C<y> is left
out >>, as pandas' C<DataFrame.hist> does: a column holding anything but numbers,
such as names, is passed over.  The columns are in numeric order when every
name is a number, and in string order otherwise.  Each column is one
distribution, so without C<by> the columns of a hash of arrays need not be the
same length.  That is the shape C<Stats::LikeR>'s C<group_by> returns, one
column per group, and it can be drawn whole:

  my $mpg_by_cyl = group_by( $mtcars, 'mpg', 'cyl' );    # { 4 => [...], 6 => [...], 8 => [...] }
  violin(
    output_file => 'mpg.svg',
    df          => $mpg_by_cyl,                         # one violin per number of cylinders
  );

=back

And things it refuses, by name:

=over

=item * a column the frame does not have, with the closest names it does have;

=item * a label repeated in C<bar>, C<barh> or C<pie>, or a label and group pair
repeated in a grouped C<bar>.  C<df> does not aggregate: use C<Stats::LikeR>'s
C<agg> or C<pivot_table> first;

=item * a grouped C<bar> missing a value for some label and group;

=item * a column named twice, a role the plot type does not read, and several
columns where only one makes sense;

=item * C<df> together with C<data>.

=back

C<df> works the same in a subplot and in an C<add> graph, each with its own frame.
C<venn_proportional_area>, C<imshow> and C<wide> do not take it.

=head2 Barplot/bar/barh

Plot a hash, a hash of arrays, or a hash of hashes as a bar chart.  C<bar> draws
vertical bars, C<barh> horizontal ones; every option below applies to both.

=head3 Entering data

C<data> accepts three shapes, and the shape alone decides whether you get one
bar per key or a group of bars per key:

B<1. One bar per key (hash of numbers).> The simplest case — the key is the
tick label:

 bar(
     output_file => '/tmp/simple.svg',
     data          => { Mon => 73, Tue => 93, Wed => 77 },
 );

B<2. Groups of bars (hash of array refs).> Each key becomes a group; index C<i>
of every array is one series, so C<color> and C<label> are arrays indexed the same
way:

 bar(
     output_file => '/tmp/grouped.svg',
     data          => {
         1941 => [ 6.6, 6.2 ],    # UK, US
         1942 => [ 7.6, 26.4 ],
     },
     color         => [ 'blue', 'gray' ],    # index 0, index 1
     label         => [ 'UK',   'US'   ],    # legend entries
 );

B<3. Groups of bars (hash of hashes).> The same picture as (2), but the series
are named by the inner keys rather than by position, so no C<label> is needed:

 bar(
     output_file => '/tmp/grouped.hoh.svg',
     data          => {
         1941 => { UK => 6.6, US => 6.2 },
         1942 => { UK => 7.6, US => 26.4 },
     },
 );

Both grouped forms accept C<< stacked =E<gt> 1 >> to pile the series on top of one
another instead of placing them side by side.

=head3 Error bars

C<yerr> (natural for C<bar>) and C<xerr> (natural for C<barh>) take either one
number for every bar, an array of one number per bar (in the order of C<key_order>, or
of the sorted keys), an array of two such arrays (the lower errors, then the upper),
or a hash keyed by the data keys.  In the hash, each value is one number, or a
two-element array giving asymmetric C<[ lower, upper ]> errors:

 bar(
     output_file => '/tmp/warheads.svg',
     data          => { USA => 5277, Russia => 5449 },
     yerr          => {
         USA    => [ 15,  29   ],    # -15, +29
         Russia => [ 199, 1000 ],
     },
     log           => 'True',
     ylabel        => '# of Nuclear Warheads',
 );

=head3 Options

=for html
<table>
<tbody>
<tr><td>Option</td><td>Description</td><td>Example</td></tr>
<tr><td>--------</td><td>-------</td><td>-------</td></tr>
<tr><td>color</td><td>:mpltype:<code>color</code> or list of :mpltype:<code>color</code>, optional; The colors of the bar faces. This is an alias for *facecolor*. If both are given, *facecolor* takes precedence # if entering multiple colors, quoting isn't needed; as of version 0.23, colors can be given as a hash, whose keys are the bars of a simple hash or the *inner* keys (the series) of a hash of hashes.  A hash of arrays has no series names to key a color hash by, and says so rather than ignoring it</td><td><code>color => ['red', 'orange', 'yellow', 'green', 'blue', 'indigo', 'fuchsia'],</code> or a single color for all bars <code>color => 'red'</code>, or as of version 0.23 <code>color => {A => 'red', B => 'green'}</code></td></tr>
<tr><td>edgecolor</td><td>:mpltype:<code>color</code> or list of :mpltype:<code>color</code>, optional; The colors of the bar edges.  For a simple hash, may also be a hash of one color per key, as <code>color</code> may; a grouped plot refuses a hash, since each of its bars is one key of one series</td><td><code>edgecolor     => 'black'</code></td></tr>
<tr><td>key_order</td><td>define the keys in an order (an array reference)</td><td><code>key_order          => ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'],</code></td></tr>
<tr><td>label</td><td>an array of legend labels for grouped bar plots, indexed like the data arrays; only meaningful for the hash-of-arrays form, since the hash-of-hashes form takes its labels from the inner keys</td><td><code>label => ['North', 'South'],</code></td></tr>
<tr><td>linewidth</td><td>float or array of one per bar, optional; Width of the bar edge(s). If 0, don't draw edges. Only does anything with defined <code>edgecolor</code></td><td><code>linewidth => 2,</code></td></tr>
<tr><td>log</td><td>bool, default: False; If *True*, set the y-axis to be log scale.  Give <code>'True'</code> or <code>'False'</code> (or 1 or 0); anything else is refused, and <code>'False'</code> turns the log scale off</td><td><code>log = 'True',</code></td></tr>
<tr><td>logscale</td><td>a synonym for <code>log</code> taking a Perl true/false value rather than Python's <code>'True'</code>/<code>'False'</code>.  Unlike the <code>logscale</code> of <code>boxplot</code>, <code>hist</code>, <code>hist2d</code>, <code>plot</code>, <code>scatter</code> and <code>violin</code>, this one is a scalar and not an array of axis names</td><td><code>logscale => 1,</code></td></tr>
<tr><td>stacked</td><td>stack the groups on top of one another; <code>'True'</code> or 1 for on, default off</td><td><code>stacked  => 1,</code></td></tr>
<tr><td>width</td><td>float only, default: 0.8; The width of the bars (their height, for <code>barh</code>).  <code>width</code> will be deactivated with grouped, non-stacked bar plots</td><td><code>width => 0.4,</code></td></tr>
<tr><td>xerr</td><td>float or array-like of shape(N,) or shape(2, N), optional. If not *None*, add horizontal / vertical errorbars to the bar tips. The values are +/- sizes relative to the data:        - scalar: symmetric +/- values for all bars #        - shape(N,): symmetric +/- values for each bar #        - shape(2, N): Separate - and + values for each bar. First row #          contains the lower errors, the second row contains the upper #          errors. #        - *None*: No errorbar. (Default)</td><td><code>yerr                       => {'USA'               => [15,29], 'Russia'            => [199,1000],}</code></td></tr>
<tr><td>yerr</td><td>same as xerr, but better with bar</td><td></td></tr>
</tbody>
</table>

an example of multiple plots, showing many options:

=head3 single, simple plot

 use Matplotlib::Simple 'plt';
 plt(
     output_file             => 'output.images/single.barplot.png',
     data    => { # simple hash
         Fri => 76, Mon  => 73, Sat => 26, Sun => 11, Thu    => 94, Tue  => 93, Wed  => 77
     },
     plot_type => 'bar',
     xlabel      => '# of Days',
     ylabel      => 'Count',
     title       => 'Customer Calls by Days'
 );

where C<xlabel>, C<ylabel>, C<title>, etc. are axis methods in matplotlib itself. C<plot_type>, C<data>, C<fh> are all specific to C<MatPlotLib::Simple>.

=for html
<p>
<img width="651" height="491" alt="single barplot" src="https://github.com/user-attachments/assets/eae009a8-5571-4608-abdb-1016e3cff5fd" />
<p>


=head3 multiple plots

 plt(
     fh                  => $fh,
     execute                => 0,
     output_file     => 'output.images/barplots.png',
     plots                   => [
     { # simple plot
             data    => { # simple hash
                 Fri => 76, Mon  => 73, Sat => 26, Sun => 11, Thu    => 94, Tue  => 93, Wed  => 77
             },
             plot_type => 'bar',
            key_order        => ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'],
             suptitle            => 'Types of Plots', # applies to all
             color               => ['red', 'orange', 'yellow', 'green', 'blue', 'indigo', 'fuchsia'],
             edgecolor       => 'black',
             set_figwidth    => 40/1.5, # applies to all plots
             set_figheight   => 30/2, # applies to all plots
             title               => 'bar: Rejections During Job Search',
             xlabel          => 'Day of the Week',
             ylabel          => 'No. of Rejections'
         },
         { # grouped bar plot
             plot_type => 'bar',
             data    => {
                 1941 => {
                    UK       => 6.6,
                    US       => 6.2,
                    USSR     => 17.8,
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
             stacked => 0,
             title       => 'Hash of Hash Grouped Unstacked Barplot',
             width       => 0.23,
             xlabel  => 'r"$\it{anno}$ $\it{domini}$"', # italic
             ylabel  => 'Military Expenditure (Billions of $)'
         },
          { # grouped bar plot
             plot_type => 'bar',
             data    => {
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
             stacked => 1,
             title       => 'Hash of Hash Grouped Stacked Barplot',
             xlabel  => 'r"$\it{anno}$ $\it{domini}$"', # italic
             ylabel  => 'Military Expenditure (Billions of $)'
         },
         {# grouped barplot: arrays indicate Union, Confederate which must be specified in options hash
             data                    => { # 4th plot: arrays indicate Union, Confederate which must be specified in options hash
              'Antietam'             => [ 12400, 10300 ],
              'Gettysburg'           => [ 23000, 28000 ],
              'Chickamauga'          => [ 16000, 18000 ],
              'Chancellorsville' => [ 17000, 13000 ],
              'Wilderness'           => [ 17500, 11000 ],
              'Spotsylvania'     => [ 18000, 12000 ],
              'Cold Harbor'          => [ 12000, 5000  ],
              'Shiloh'               => [ 13000, 10700 ],
              'Second Bull Run'  => [ 10000, 8000  ],
              'Fredericksburg'       => [ 12600, 5300  ],
             },
             plot_type => 'barh',
             color       =>  ['blue', 'gray'], # colors match indices of data arrays
             label       => ['North', 'South'], # colors match indices of data arrays
             xlabel  => 'Casualties',
             ylabel  => 'Battle',
             title       => 'barh: hash of array'
         },
         { # 5th plot: barplot with groups
             data    => {
                 1942 => [ 109867,  310000, 7700000 ], # US, Japan, USSR
                 1943 => [ 221111,  440000, 9000000 ],
                 1944 => [ 318584,  610000, 7000000 ],
                 1945 => [ 318929, 1060000, 3000000 ],
             },
             color       => ['blue', 'pink', 'red'], # colors match indices of data arrays
             label       => ['USA', 'Japan', 'USSR'], # colors match indices of data arrays
             'log'       => 1,
             title       => 'grouped bar: Casualties in WWII',
             ylabel  => 'Casualties',
             plot_type => 'bar'
         },
         { # nuclear weapons barplot
             plot_type       => 'bar',
             data => {
                 'USA'               => 5277, # FAS Estimate
                 'Russia'            => 5449, # FAS Estimate
                 'UK'                => 225, # Consistent estimate
                 'France'            => 290, # Consistent estimate
                 'China'         => 600, # FAS Estimate
                 'India'         => 180, # FAS Estimate
                 'Pakistan'      => 130, # FAS Estimate
                 'Israel'            => 90, # FAS Estimate
                 'North Korea'   => 50, # FAS Estimate
             },
             title       => 'Simple hash for barchart with yerr',
             xlabel  => 'Country',
             yerr                        => {
                 'USA'               => [15,29],
                 'Russia'            => [199,1000],
                 'UK'                => [15,19],
                 'France'            => [19,29],
                 'China'         => [200,159],
                 'India'         => [15,25],
                 'Pakistan'      => [15,49],
                 'Israel'            => [90,50],
                 'North Korea'   => [10,20],
             },
             ylabel  => '# of Nuclear Warheads',
             'log'                       => 'True', #    linewidth               => 1,
         }
     ],
     ncols   => 3,
     nrows   => 4
 );

which produces the plot:


=for html
<p>
<img width="2678" height="849" alt="barplots" src="https://github.com/user-attachments/assets/6d87d13b-dabd-485d-92f7-1418f4acc65b" />
<p>


=head3 colors for each hash key defined by hash

 plt(
     plots => [
         {
             color        => {
                 A => 'red', B => 'green', C => 'blue'
             },
             data => {
                 A => 1, B => 2, C => 3
             },
             plot_type     => 'bar'
         },
         {
             color        => {
                 A => 'red', B => 'green', C => 'blue'
             },
             data => {
                 A => 1, B => 2, C => 3
             },
             plot_type     => 'barh'
         },
     ],
     ncols         => 2,
     output_file => '/tmp/key.colors.bar.svg',
 );

which produces the plot


=for html
<p>
<img width="651" height="491" alt="key colors bar" src="https://github.com/user-attachments/assets/0eab9c75-7e87-4297-b45d-86e5d7ffc550" />
<p>


=head2 boxplot

Plot a hash of arrays as a series of boxplots: one box per key, labelled with
the key and the number of points it holds.

=head3 Entering data

Ordinarily C<data> is a hash of array refs, one array per box:

 boxplot(
     output_file => '/tmp/boxes.svg',
     data          => { A => \@a, B => \@b, C => \@c },
 );

A bare array ref is the one-box shorthand; the box gets an empty label:

 boxplot(
     output_file => '/tmp/one.box.svg',
     data          => \@a,
 );

Undefined values are dropped rather than fatal, so a column read out of a
spreadsheet with blank cells can be handed over as-is; a value that is present
but not a number is an error naming the offending key.  (L<#violin>
takes exactly these two shapes as well — swapping C<< 'plot_type' =E<gt> 'boxplot' >>
for C<< 'plot_type' =E<gt> 'violinplot' >> is a one-word change — but it drops
non-numeric values silently instead of dying.)

=head3 options

=for html
<table>
<tbody>
<tr><td>Option</td><td>Description</td><td>Example</td></tr>
<tr><td>--------</td><td>-------</td><td>-------</td></tr>
<tr><td><code>color</code></td><td>a single color for all boxes</td><td><code>color => 'pink'</code></td></tr>
<tr><td><code>colors</code></td><td>a hash pairing each data key with its own color.  Every key in <code>data</code> must appear, otherwise the call dies naming the keys that have no color</td><td><code>colors => { A => 'orange', E => 'yellow', B => 'purple' },</code></td></tr>
<tr><td><code>key_order</code></td><td>order that the keys in the entry hash will be plotted</td><td><code>key_order => ['A', 'E', 'B']</code></td></tr>
<tr><td><code>logscale</code></td><td>an array of the axes to put on a log scale; only <code>x</code> and <code>y</code> are accepted</td><td><code>logscale => ['y']</code></td></tr>
<tr><td><code>notch</code></td><td>draw a notched box (<code>'True'</code>) instead of a rectangular one</td><td><code>notch => 'True'</code></td></tr>
<tr><td><code>orientation</code></td><td>orientation of the plot, by default <code>vertical</code></td><td><code>orientation => 'horizontal'</code></td></tr>
<tr><td><code>showcaps</code></td><td>Show the caps on the ends of whiskers; default <code>True</code></td><td><code>showcaps => 'False',</code></td></tr>
<tr><td><code>showfliers</code></td><td>Show the outliers beyond the caps; default <code>True</code></td><td><code>showfliers  => 'False'</code></td></tr>
<tr><td><code>showmeans</code></td><td>show means; default = <code>True</code></td><td><code>showmeans   => 'False'</code></td></tr>
</tbody>
</table>

C<showcaps>, C<showfliers>, C<showmeans> and C<notch> take Python's C<'True'>/C<'False'>,
in any case, or 1 or 0; anything else is refused by name.
The C<whiskers> switch belongs to L<#violin>, not to C<boxplot>.

=head3 single, simple plot

 my $x = generate_normal_dist( 100, 15, 3 * 10 );
 my $y = generate_normal_dist( 85,  15, 3 * 10 );
 my $z = generate_normal_dist( 106, 15, 3 * 10 );

single plots are simple

 use Matplotlib::Simple 'boxplot';
 boxplot(
     output_file => 'output.images/single.boxplot.png',
     data              => {                                     # simple hash
         E => [ 55,    @{$x}, 160 ],
         B => [ @{$y}, 140 ],
 
         #       A => @a
     },
     title        => 'Single Box Plot: Specified Colors',
     colors       => { E => 'yellow', B => 'purple' },
     fh           => $fh,
     execute      => 0,
 );

which makes the following image:


=for html
<p>
<img width="651" height="491" alt="single boxplot" src="https://github.com/user-attachments/assets/19870fa2-fe36-4513-8cbb-23da3a0cf686" />
<p>


=head3 multiple plots

 plt(
     output_file => 'output.images/boxplot.png',
     execute           => 0,
     fh                => $fh,
     plots             => [
         {
             data => {
                 A => [ 55, @{$z} ],
                 E => [ @{$y} ],
                 B => [ 122, @{$z} ],
             },
             title       => 'Simple Boxplot',
             ylabel      => 'ylabel',
             xlabel      => 'label',
             plot_type => 'boxplot',
             suptitle    => 'Boxplot examples'
         },
         {
             color => 'pink',
             data  => {
                 A => [ 55, @{$z} ],
                 E => [ @{$y} ],
                 B => [ 122, @{$z} ],
             },
             title       => 'Specify single color',
             ylabel      => 'ylabel',
             xlabel      => 'label',
             plot_type => 'boxplot'
         },
         {
             colors => {
                 A => 'orange',
                 E => 'yellow',
                 B => 'purple'
             },
             data => {
                 A => [ 55, @{$z} ],
                 E => [ @{$y} ],
                 B => [ 122, @{$z} ],
             },
             title       => 'Specify set-specific color; showfliers = False',
             ylabel      => 'ylabel',
             xlabel      => 'label',
             plot_type => 'boxplot',
             showmeans   => 'True',
             showfliers  => 'False',
             set_figwidth => 12
         },
         {
             colors => {
                 A => 'orange',
                 E => 'yellow',
                 B => 'purple'
             },
             data => {
                 A => [ 55, @{$z} ],
                 E => [ @{$y} ],
                 B => [ 122, @{$z} ],
             },
             title       => 'Specify set-specific color; showmeans = False',
             ylabel      => 'ylabel',
             xlabel      => 'label',
             plot_type => 'boxplot',
             showmeans   => 'False',
         },
         {
             colors => {
                 A => 'orange',
                 E => 'yellow',
                 B => 'purple'
             },
             data => {
                 A => [ 55, @{$z} ],
                 E => [ @{$y} ],
                 B => [ 122, @{$z} ],
             },
             title       => 'Set-specific color; orientation = horizontal',
             ylabel      => 'ylabel',
             xlabel      => 'label',
             orientation => 'horizontal',
             plot_type => 'boxplot',
         },
         {
             colors => {
                 A => 'orange',
                 E => 'yellow',
                 B => 'purple'
             },
             data => {
                 A => [ 55, @{$z} ],
                 E => [ @{$y} ],
                 B => [ 122, @{$z} ],
             },
             title       => 'Notch = True',
             ylabel      => 'ylabel',
             xlabel      => 'label',
             notch       => 'True',
             plot_type => 'boxplot',
         },
         {
             colors => {
                 A => 'orange',
                 E => 'yellow',
                 B => 'purple'
             },
             data => {
                 A => [ 55, @{$z} ],
                 E => [ @{$y} ],
                 B => [ 122, @{$z} ],
             },
             title         => 'showcaps = False',
             ylabel        => 'ylabel',
             xlabel        => 'label',
             showcaps      => 'False',
             plot_type     => 'boxplot',
             set_figheight => 12,
         },
     ],
     ncols => 3,
     nrows => 3,
 );

which makes the following plot:


=for html
<p>
<img width="1230" height="1211" alt="boxplot" src="https://github.com/user-attachments/assets/7e32e394-86fc-49e7-ad97-f48fd82fc8b0" />
<p>


=head2 Colored Table

Plot a hash of hashes as a matrix, coloring each cell by its value.

=head3 Entering data

C<data> is a hash of hashes: the outer key is the row, the inner key is the
column, and the value is the number that picks the cell's color.

 colored_table(
     output_file => '/tmp/matrix.svg',
     data          => {
         H => { H => 432, Cl => 427, Br => 363 },
         C => { H => 413, Cl => 339, Br => 276 },
     },
 );

The matrix does not have to be complete.  Cells with no value are left out of
the color scale and drawn in C<undef_color> (gray by default), and a table that
only fills one triangle — the usual shape of a pairwise-comparison table — can
be completed by reflecting it across the diagonal with C<< mirror =E<gt> 1 >>, so that
C<$data{A}{B}> also supplies C<$data{B}{A}>.

The rows are the outer keys and the columns every inner key, each in sorted
order, so the table above has rows C and H and columns Br, Cl and H.  With
C<mirror>, which makes the table symmetric, rows and columns are both every key.
C<col_labels> chooses which keys are drawn and in what order, as the rows and the
columns both, which is how the bond-dissociation example below shows the
halogens only out of a larger table; C<row_labels> supplies the text down the
left-hand side, so it should list the same keys in the same order, and must have
one label per row.

=head3 options

=for html
<table>
<tbody>
<tr><td>Option</td><td>Description</td><td>Example</td></tr>
<tr><td>--------</td><td>-------</td><td>-------</td></tr>
<tr><td><code>cb_logscale</code></td><td>color the cells on a log scale</td><td><code>cb_logscale => 1</code></td></tr>
<tr><td><code>cb_min</code>, <code>cb_max</code></td><td>clamp the ends of the color scale instead of taking them from the data, so several tables can be compared directly</td><td><code>cb_min => 100, cb_max => 500</code></td></tr>
<tr><td><code>cblabel</code></td><td>the label on the colorbar</td><td><code>cblabel => 'kJ/mol'</code></td></tr>
<tr><td><code>cmap</code></td><td>the colormap used for coloring the cells</td><td><code>cmap => 'viridis'</code></td></tr>
<tr><td><code>col_labels</code></td><td>array ref: which keys to draw, in order — this selects the rows and the columns of the matrix, not just the heading text</td><td><code>col_labels => ['H', 'F', 'Cl', 'Br', 'I']</code></td></tr>
<tr><td><code>colorbar_on</code></td><td>draw the colorbar; on by default, <code>0</code> turns it off, <code>cblabel</code> or no <code>cblabel</code></td><td><code>colorbar_on => 0</code></td></tr>
<tr><td><code>mirror</code></td><td>treat the table as symmetric: <code>$data{A}{B}</code> also fills <code>$data{B}{A}</code></td><td><code>mirror => 1</code></td></tr>
<tr><td><code>row_labels</code></td><td>array ref of the labels printed down the left side; give it the same keys, in the same order, as <code>col_labels</code></td><td><code>row_labels => ['H', 'F', 'Cl', 'Br', 'I']</code></td></tr>
<tr><td><code>show_numbers</code></td><td>print each cell's value in the cell; off by default</td><td><code>show_numbers => 1</code></td></tr>
<tr><td><code>undef_color</code></td><td>the color for cells that have no value; gray by default</td><td><code>undef_color => 'white'</code></td></tr>
<tr><td><code>default_undefined</code></td><td>the value a cell with no value takes, instead of being left empty.  It counts towards the color scale like any other value, so <code>undef_color</code> no longer applies to those cells</td><td><code>default_undefined => 0</code></td></tr>
</tbody>
</table>

The colorbar options in L<#color-bars-colorbars> — C<cbdrawedges>,
C<cblocation>, C<cborientation>, C<cbpad> — work here too.

=head3 Single, simple plot

the bond dissociation energy table can be plotted:

 # https://labs.chem.ucsb.edu/zakarian/armen/11---bonddissociationenergy.pdf and https://chem.libretexts.org/Bookshelves/Physical_and_Theoretical_Chemistry_Textbook_Maps/Supplemental_Modules_(Physical_and_Theoretical_Chemistry)/Chemical_Bonding/Fundamentals_of_Chemical_Bonding/Bond_Energies
 my %bond_dissociation = (
     Br =>  {
       Br =>  193
     },
     C  =>  {
         Br =>  276, C  =>  347, Cl =>  339, F   => 485, H  =>  413, I  =>  240,
         N  =>  305, O  =>  358, S  =>  259
     },
     Cl =>  {
         Br =>  218, Cl =>  239
     },
     F =>   {
         I => 280, Br =>  237, Cl  => 253, F   => 154
     },
     H  =>  {
         Br =>  363, Cl =>  427, F  =>  565, H   => 432, I   => 295
     },
     I  =>  {
         Br  => 175, Cl =>  208, I  =>  149
     },
     N  =>  {
         Br =>  243, Cl  => 200, F   => 272, H  =>  391, N  =>  160, O  =>  201
     },
     O =>   {
         Cl =>  203, F  =>  190, H  =>  467, I  =>  234, O  =>  146
     },
     S  =>  {
         Br => 218,  Cl => 253,  F  => 327,  H  => 347,  S  => 266
     },
     Si => {
         C  => 360, H  => 393, O  => 452,    Si => 340
     }
 );

and the plot itself:

 colored_table(
     'cblabel'     => 'kJ/mol',
     col_labels    => ['H', 'F', 'Cl', 'Br', 'I'],
     data          => \%bond_dissociation,
     execute       => 0,
     fh            => $fh,
     mirror        => 1,
     output_file => 'output.images/single.tab.png',
     row_labels    => ['H', 'F', 'Cl', 'Br', 'I'],
     show_numbers=> 1,
     set_title     => 'Bond Dissociation Energy'
 );

which makes the following image:


=for html
<p>
<img width="584" height="491" alt="single tab" src="https://github.com/user-attachments/assets/d890830b-a502-4d51-b118-20aeae0473e8" />
<p>


=head3 Multiple Plots

 plt(
     output_file => 'output.images/tab.multiple.png',
     execute       => 0,
     fh            => $fh,
     plots         => [
         {
             data          => \%bond_dissociation,
             plot_type     => 'colored_table',
             set_title     => 'No other options'
         },
         {
             data          => \%bond_dissociation,
             cblabel       => 'Average Dissociation Energy (kJ/mol)',
             col_labels    => ['H', 'C', 'N', 'O', 'F', 'Si', 'S', 'Cl', 'Br', 'I'],
             mirror        => 1,
             plot_type     => 'colored_table',
             row_labels    => ['H', 'C', 'N', 'O', 'F', 'Si', 'S', 'Cl', 'Br', 'I'],
             show_numbers=> 1,
             set_title     => 'Showing numbers and mirror with defined order'
         },
         {
             data          => \%bond_dissociation,
             cblabel       => 'Average Dissociation Energy (kJ/mol)',
             col_labels    => ['H', 'C', 'N', 'O', 'F', 'Si', 'S', 'Cl', 'Br', 'I'],
             mirror        => 1,
             plot_type     => 'colored_table',
             row_labels    => ['H', 'C', 'N', 'O', 'F', 'Si', 'S', 'Cl', 'Br', 'I'],
             show_numbers=> 1,
             set_title     => 'Set undefined color to white',
             undef_color => 'white'
         }
     ],
     ncols         => 3,
     set_figwidth  => 14,
     suptitle      => 'Colored Table options'
 );

which makes the following plot:


=for html
<p>
<img width="1410" height="491" alt="tab multiple" src="https://github.com/user-attachments/assets/be836742-cc5b-4618-a0c8-a0ee57856eb1" />
<p>


=head2 hexbin

Plot a hash of arrays as a hexbin
see https://matplotlib.org/stable/api/I<as>gen/matplotlib.pyplot.hexbin.html

A hexbin answers the question a scatterplot stops answering once there are tens
of thousands of points: instead of drawing every point and letting them pile up
into an indistinguishable blob, the plane is tiled with hexagons and each one is
colored by how many points fell inside it.

=head3 Entering data

C<data> is a hash of exactly B<two> array refs of equal length — the first key
(sorted) is the x-axis, the second is the y-axis, and both become the axis
labels.  Use C<key_order> to say which is which rather than relying on the sort:

 hexbin(
     output_file => '/tmp/hex.svg',
     data          => { Height => \@heights, Weight => \@weights },
     key_order     => [ 'Weight', 'Height' ],    # Weight on x
     cblabel       => 'people per cell',
 );

=head3 options

=for html
<table>
<tbody>
<tr><td>Option</td><td>Description</td><td>Example</td></tr>
<tr><td>--------</td><td>-------</td><td>-------</td></tr>
<tr><td>cb_logscale</td><td>colorbar log scale <code>from matplotlib.colors import LogNorm</code></td><td>default 0, any value > 0 enables</td></tr>
<tr><td>cblabel</td><td>the label on the colorbar, i.e. what the cell counts mean; <code>Density</code> if not given</td><td><code>cblabel => 'observations'</code></td></tr>
<tr><td>cmap</td><td>The Colormap instance or registered colormap name used to map scalar data to colors</td><td>default <code>gist_rainbow</code></td></tr>
<tr><td>key_order</td><td>define the keys in an order (an array reference)</td><td><code>key_order => ['X-rays', 'Yak Butter'],</code></td></tr>
<tr><td>marginals</td><td>integer, by default off = 0</td><td><code>marginals => 1</code></td></tr>
<tr><td>mincnt</td><td>int >= 0, default: None; If not None, only display cells with at least mincnt number of points in the cell.</td><td><code>mincnt => 2</code></td></tr>
<tr><td>vmax</td><td>the cell count at the top of the color scale; taken from the data if not given</td><td><code>vmax => 50</code></td></tr>
<tr><td>vmin</td><td>the cell count at the bottom of the color scale; taken from the data if not given</td><td><code>vmin => 1</code></td></tr>
<tr><td>xbins</td><td>integer that accesses horizontal gridsize</td><td>default is 15</td></tr>
<tr><td>xscale_hexbin</td><td>'linear', 'log'}, default: 'linear': Use a linear or log10 scale on the horizontal axis</td><td><code>xscale_hexbin => 'log'</code></td></tr>
<tr><td>ybins</td><td>integer that accesses vertical gridsize</td><td>default is 15</td></tr>
<tr><td>yscale_hexbin</td><td>'linear', 'log'}, default: 'linear': Use a linear or log10 scale on the vertical axis</td><td><code>yscale_hexbin => 'log'</code></td></tr>
</tbody>
</table>

With C<cb_logscale>, C<vmin> and C<vmax> set the ends of the C<LogNorm> that draws
the log-scaled colorbar, as they do for C<hist2d>.

=head3 single, simple plot

 plt(
     data    => {
         E   => generate_normal_dist(100, 15, 3*210),
         B   => generate_normal_dist(85, 15, 3*210)
     },
     output_file     => 'output.images/single.hexbin.png',
     plot_type => 'hexbin',
     set_figwidth => 12,
     title           => 'Simple Hexbin',
 );

which makes the following plot:

=for html
<p>
<img width="1208" height="491" alt="single hexbin" src="https://github.com/user-attachments/assets/129c41cd-2d7d-43de-978a-2b9c441b8939" />
<p>


=head3 multiple plots

 plt(
     fh => $fh,
     execute           => 0,
     output_file => 'output.images/hexbin.png',
     plots             => [
         {
             data => {
             E => @e,
             B => @b
             },
             plot_type    => 'hexbin',
             title        => 'Simple Hexbin',
         },
         {
             data => {
                 E => @e,
                 B => @b
             },
             plot_type => 'hexbin',
             title       => 'colorbar logscale',
             cb_logscale => 1
         },
         {
             cmap => 'jet',
             data => {
                 E => @e,
                 B => @b
             },
             plot_type    => 'hexbin',
             title        => 'cmap is jet',
             xlabel       => 'xlabel',
         },
          {
             data => {
                 E => @e,
                 B => @b
             },
             key_order    => ['E', 'B'],
             plot_type    => 'hexbin',
             title        => 'Switch axes with key_order',
         },
          {
             data => {
                 E => @e,
                 B => @b
             },
             plot_type    => 'hexbin',
             title        => 'vmax set to 25',
             vmax         => 25
         },
          {
             data => {
                 E => @e,
                 B => @b
             },
             plot_type    => 'hexbin',
             title        => 'vmin set to -4',
             vmin         => -4
         },
         {
             data => {
                 E => @e,
                 B => @b
             },
             plot_type    => 'hexbin',
             title        => 'mincnt set to 7',
             mincnt       => 7
         },
         {
             data => {
                 E => @e,
                 B => @b
             },
             plot_type    => 'hexbin',
             title        => 'xbins set to 9',
             xbins        => 9
         },
         {
             data => {
                 E => @e,
                 B => @b
             },
             plot_type    => 'hexbin',
             title        => 'ybins set to 9',
             ybins        => 9
         },
         {
             data => {
                 E => @e,
                 B => @b
             },
             plot_type    => 'hexbin',
             title        => 'marginals = 1',
             marginals    => 1
         },
         {
             data => {
                 E => @e,
                 B => @b
             },
             plot_type    => 'hexbin',
             title        => 'xscale_hexbin = 1',
             xscale_hexbin => 'log'
         },
         {
             data => {
                 E => @e,
                 B => @b
             },
             plot_type    => 'hexbin',
             title        => 'yscale_hexbin = 1',
             yscale_hexbin => 'log'
         },
     ],
     ncols        => 4,
     nrows        => 3,
     scale        => 5,
     suptitle     => 'Various Changes to Standard Hexbin: All data is the same'
 );

which produces the following image:

=for html
<p>
<img width="2409" height="3211" alt="hexbin" src="https://github.com/user-attachments/assets/0b23a0cb-8f9a-43fb-8da1-0debee13d540" />
<p>


=head2 hist

Plot a hash of arrays as a series of histograms, one per key, drawn over each
other in the same axes — C<alpha> defaults to 0.5 so that the overlaps stay
readable.  A single array ref is the one-set shorthand.  Values must be numeric:
unlike C<boxplot> and C<violin>, a non-numeric value here is an error.

Each set is binned separately, so with C<< bins =E<gt> 50 >> two sets covering different
ranges get 50 bins each over their own range rather than a common set of edges.
When the sets must line up exactly — which is what makes the bar heights
comparable — pass the edges themselves rather than a count:

 hist(
     output_file => '/tmp/hist.svg',
     data          => { E => \@e, B => \@b },
     bins          => [ map { 10 * $_ } 0 .. 20 ],    # shared edges, 0..200
 );

C<bins> and C<color> also accept a B<hash keyed by set>, for when one
distribution wants different treatment from the others:

     bins  => { E => 50, B => 20 },
     color => { E => 'orange', B => 'black' },

The legend is on by default when there is more than one set and off when there is
only one; C<show_legend> overrides that either way.

Every subplot drawn with C<hist> reports the range of its bin heights on STDOUT,
over all of the sets drawn into it, as

 plot 0 hist range = [1, 12]

where the number is the subplot's index — C<plot 1> is the second subplot of a
figure — and the range is C<[shortest bar, tallest bar]>.  The heights are
matplotlib's, counted as the figure is drawn: this module does not bin the data,
so there is no way to know them without asking.  Nothing about the figure
changes because they are reported; the file written to C<output_file> is the
same either way.

=head3 options

=for html
<table>
<tbody>
<tr><td>Option</td><td>Description</td><td>Example</td></tr>
<tr><td>--------</td><td>-------</td><td>-------</td></tr>
<tr><td><code>alpha</code></td><td>opacity of the bars, default 0.5; the same value is used for all sets</td><td><code>alpha => 0.25</code></td></tr>
<tr><td><code>bins</code></td><td>int or sequence or str, default: :rc:<code>hist.bins</code>.  If *bins* is an integer, it defines the number of equal-width bins in the range. If *bins* is a sequence, it defines the bin edges, including the left edge of the first bin and the right edge of the last bin; in this case, bins may be unequally spaced.  All but the last  (righthand-most) bin is half-open.  May also be a hash keyed by set</td><td><code>bins => 50</code></td></tr>
<tr><td><code>color</code></td><td>either one color for every set, or a hash pairing each data key with its own color.  A key of the hash that is not a set of <code>data</code> is refused, and so is one of a <code>bins</code> hash</td><td><code>color => { X => 'blue', Y => 'orange' }</code></td></tr>
<tr><td><code>key_order</code></td><td>the order the sets are drawn in, and so the order of the legend; sorted by name by default</td><td><code>key_order => ['Y', 'X']</code></td></tr>
<tr><td><code>logscale</code></td><td>an array of the axes to put on a log scale, useful when one set is orders of magnitude rarer than another.  It must be an array reference — <code>logscale => 1</code> is an error</td><td><code>logscale => ['y']</code></td></tr>
<tr><td><code>orientation</code></td><td>{'vertical', 'horizontal'}, default: 'vertical'; one for every set, which share an axes</td><td><code>orientation => 'horizontal'</code></td></tr>
<tr><td><code>show_legend</code></td><td>on when <code>data</code> holds more than one set, off when it holds one; set it explicitly to override</td><td><code>show_legend => 0</code></td></tr>
</tbody>
</table>

=head3 single, simple plot

as of version 0.26, single arrays can be given to C<hist> instead of a hash, simplifying the call:

 hist(
     data          => [0..9],
     output_file => '/tmp/hist.arr.svg',
 );

for slightly more complex data sets, hashes are taken:

 use Matplotlib::Simple 'hist';
 
 my @e = generate_normal_dist( 100, 15, 3 * 200 );
 my @b = generate_normal_dist( 85,  15, 3 * 200 );
 my @a = generate_normal_dist( 105, 15, 3 * 200 );
 
 hist(
     fh => $fh,
     execute           => 0,
     output_file => 'output.images/single.hist.png',
     data              => {
         E => @e,
         B => @b,
         A => @a,
     }
 );

which makes the following simple plot:


=for html
<p>
<img width="651" height="491" alt="single hist" src="https://github.com/user-attachments/assets/fafcf787-6c4f-4998-88c4-77a15d878fa6" />
<p>


=head3 multiple plots

 plt(
     fh => $fh,
     execute           => 0,
     output_file => 'output.images/histogram.png',
    set_figwidth => 15,
    suptitle          => 'hist Examples',
     plots             => [
         { # 1st subplot
             data => {
                 E => @e,
                 B => @b,
                 A => @a,
             },
             plot_type => 'hist',
             alpha       => 0.25,
             bins        => 50,
             title       => 'alpha = 0.25',
             color       => {
                 B => 'Black',
                 E => 'Orange',
                 A => 'Yellow',
             },
             scatter => '['
               . join( ',', 22 .. 44 ) . '],['  # x coords
               . join( ',', 22 .. 44 )          # y coords
               . '], label = "scatter"',
             xlabel   => 'Value',
             ylabel   => 'Frequency',
         },
         { # 2nd subplot
             data => {
                 E => @e,
                 B => @b,
                 A => @a,
             },
             plot_type => 'hist',
             alpha       => 0.75,
             bins        => 50,
             title       => 'alpha = 0.75',
             color       => {
                 B => 'Black',
                 E => 'Orange',
                 A => 'Yellow',
             },
             xlabel   => 'Value',
             ylabel   => 'Frequency',
         },
         { # 3rd subplot
             add               => [ # add secondary plots/graphs/methods
             { # 1st additional plot/graph
                 data              => {
                     'Gaussian'       => [
                         [40..150],
                         [map {150 * exp(-0.5*($_-100)**2)} 40..150]
                     ]
                 },
                 plot_type => 'plot',
                 set_options => {
                     'Gaussian' =>  'color = "red", linestyle = "dashed"'
                 }
             }
             ],
            data => {
                 E => @e,
                 B => @b,
                 A => @a,
             },
             plot_type => 'hist',
             alpha       => 0.75,
             bins        => {
                 A => 10,
                 B => 25,
                 E => 50
             },
             title => 'Varying # of bins',
             color => {
                 B => 'Black',
                 E => 'Orange',
                 A => 'Yellow',
             },
             xlabel       => 'Value',
             ylabel       => 'Frequency',
         },
         {# 4th subplot
             data => {
                 E => @e,
                 B => @b,
                 A => @a,
             },
             plot_type => 'hist',
             alpha       => 0.75,
             color       => {
                 B => 'Black',
                 E => 'Orange',
                 A => 'Yellow',
             },
             orientation  => 'horizontal',    # assign x and y labels smartly
             title        => 'Horizontal orientation',
             ylabel       => 'Value',
             xlabel       => 'Frequency',                #               'log'                   => 1,
         },
     ],
     ncols => 3,
     nrows => 2,
 );


=for html
<p>
<img width="1511" height="491" alt="histogram" src="https://github.com/user-attachments/assets/b13b4cc8-6e64-40b0-913d-6a5886cee0db" />
<p>


=head2 hist2d

Make a 2-D histogram from a hash of arrays: like L<#hexbin>, C<data> is
a hash of exactly B<two> equal-length array refs, the first (sorted) key giving
the x-axis and the second the y-axis, and the plane is divided into rectangular
cells colored by how many points landed in each.  C<hexbin> and C<hist2d> are
interchangeable on the same data — hexagons tile the plane without the visual
grid artefacts of squares, while square bins are easier to read off against the
axes.

=head3 single, simple plot

 plt(
     output_file => 'output.images/single.hist2d.png',
     data              => {
         E => @e,
         B => @b
     },
     plot_type    => 'hist2d',
     title        => 'title',
     execute      => 0,
     fh => $fh,
 );

makes the following image:


=for html
<p>
<img width="650" height="491" alt="single hist2d" src="https://github.com/user-attachments/assets/86480c77-7b8f-4bfa-b5d8-71f82830260f" />
<p>


the range for the density min and max is reported to stdout

=head3 options

=for html
<table>
<tbody>
<tr><td>Option</td><td>Description</td><td>Example</td></tr>
<tr><td>--------</td><td>-------</td><td>-------</td></tr>
<tr><td><code>cb_logscale</code></td><td>make the colorbar log-scale</td><td><code>cb_logscale => 1</code></td></tr>
<tr><td><code>cblabel</code></td><td>the label on the colorbar, i.e. what the cell counts mean; <code>Density</code> if not given</td><td><code>cblabel => 'observations'</code></td></tr>
<tr><td><code>cmap</code></td><td>color map for coloring # "gist_rainbow" by default</td><td></td></tr>
<tr><td>'cmax', <code>cmin</code></td><td>All bins that has count < *cmin* or > *cmax* will not be displayed.  <code>cmin => 1</code> is the usual way to leave empty cells blank instead of coloring them as zero</td><td><code>cmin => 1</code></td></tr>
<tr><td>'density'</td><td>density : bool, default: False; normalise the counts so the plot shows a probability density instead of raw counts, which is what makes two plots of different-sized samples comparable</td><td><code>density => 'True'</code></td></tr>
<tr><td>'key_order'</td><td>define the keys in an order (an array reference), i.e. which key is the x-axis</td><td><code>key_order => ['Y', 'X']</code></td></tr>
<tr><td>'logscale'</td><td>an array of the axes that will get a log scale</td><td><code>logscale => ['x']</code></td></tr>
<tr><td>'show_colorbar'</td><td>self-evident, 0 or 1; a synonym for <code>colorbar_on</code>, either of which suppresses the colorbar (before 0.3132 only this one did)</td><td><code>show_colorbar</code> => 0</td></tr>
<tr><td>'vmax'</td><td>When using scalar data and no explicit *norm*, *vmin* and *vmax* define the data range that the colormap cover</td><td></td></tr>
<tr><td>'vmin'</td><td># When using scalar data and no explicit *norm*, *vmin* and *vmax* define the data range that the colormap cover</td><td></td></tr>
<tr><td>'xbins'</td><td># default 15</td><td></td></tr>
<tr><td>'xmin', 'xmax',</td><td></td><td></td></tr>
<tr><td>'ymin', 'ymax',</td><td></td><td></td></tr>
<tr><td>'ybins'</td><td>default 15</td><td></td></tr>
</tbody>
</table>

=head3 multiple plots

 plt(
     fh => $fh,
     execute           => 1,
     ncols             => 3,
     nrows             => 3,
     suptitle          => 'Types of hist2d plots: all of the data is identical',
     plots => [
         {
             data => {
             X => $x,    # x-axis
             Y => $y,    # y-axis
             },
             plot_type => 'hist2d',
             title       => 'Simple hist2d',
         },
         {
             data => {
                 X => $x,    # x-axis
                 Y => $y,    # y-axis
             },
             plot_type => 'hist2d',
             title       => 'cmap = terrain',
             cmap        => 'terrain'
         },
         {
             cmap => 'ocean',
             data => {
                 X => $x,    # x-axis
                 Y => $y,    # y-axis
             },
             plot_type => 'hist2d',
             title => 'cmap = ocean and set colorbar range with vmin/vmax',
             set_figwidth => 15,
             vmin         => -2,
             vmax         => 14
         },
         {
             data => {
                 X => $x,    # x-axis
                 Y => $y,    # y-axis
             },
             plot_type => 'hist2d',
             title       => 'density = True',
             cmap        => 'terrain',
             density     => 'True'
         },
         {
             data => {
                 X => $x,    # x-axis
                 Y => $y,    # y-axis
             },
             plot_type => 'hist2d',
             title       => 'key_order flips axes',
             cmap        => 'terrain',
             key_order => [ 'Y', 'X' ]
         },
         {
             cb_logscale => 1,
             data => {
                 X => $x,    # x-axis
                 Y => $y,    # y-axis
             },
             plot_type => 'hist2d',
             title       => 'cb_logscale = 1',
         },
         {
             cb_logscale => 1,
             data => {
                 X => $x,    # x-axis
                 Y => $y,    # y-axis
             },
             plot_type => 'hist2d',
             title       => 'cb_logscale = 1 with vmax set',
             vmax        => 2.1,
             vmin        => 1
         },
         {
             data => {
                 X => $x,    # x-axis
                 Y => $y,    # y-axis
             },
             plot_type       => 'hist2d',
             show_colorbar => 0,
             title           => 'no colorbar',
         },
         {
             data => {
                 X => $x,    # x-axis
                 Y => $y,    # y-axis
             },
             plot_type       => 'hist2d',
             title           => 'xbins = 9',
             xbins           => 9
         },
     ],
     output_file => 'output.images/hist2d.png',
 );

makes the following image:


=for html
<p>
<img width="1510" height="491" alt="hist2d" src="https://github.com/user-attachments/assets/3d6becd3-44f3-4511-8b0f-eae39bc325fa" />
<p>


=head2 imshow

Plot 2D array of numbers as an image

=head3 Entering data

C<data> is a 2-D array — an array of array refs — and nothing else; a hash is an
error.  The generated call leaves Matplotlib's C<origin> at its default, so row
C<0> is drawn at the B<top>; use C<invert_yaxis> if your first row is meant to be
the bottom of the picture:

 my @grid;
 foreach my $i (0 .. 360) {
     foreach my $j (0 .. 360) {
         push @{ $grid[$i] }, sin($i * $pi/180) * cos($j * $pi/180);
     }
 }
 imshow(
     output_file => '/tmp/grid.svg',
     data          => \@grid,
     cblabel       => 'sin(x) * cos(x)',
 );

The cells may hold B<strings> instead of numbers, as long as C<stringmap> gives
the meaning of each one — without it, non-numeric data is an error.  Each string
is assigned an integer, the image is drawn with one discrete color per string,
and the colorbar's ticks are labelled with the names from C<stringmap> rather than
with numbers.  (C<cmap> is dropped, with a warning, when strings are in play,
since the palette has to be a discrete one.)  This is what makes C<imshow> usable
for categorical rasters — sequence annotation, land cover, state-over-time
diagrams — and there is a worked example under
L<#secondary-structure-prediction-dssp>.

Because C<imshow> produces a colorbar per subplot, C<shared_colorbar> is often
worth setting when several panels show the same quantity: it gives them one
colorbar, and hence one color scale, so the panels can be compared.

=head3 options

=for html
<table>
<tbody>
<tr><td>Option</td><td>Description</td><td>Example</td></tr>
<tr><td>--------</td><td>-------</td><td>-------</td></tr>
<tr><td><code>cblabel</code></td><td>colorbar label</td><td><code>cblabel => 'sin(x) * cos(x)',</code></td></tr>
<tr><td><code>cbdrawedges</code></td><td>draw edges for colorbar</td><td></td></tr>
<tr><td><code>cblocation</code></td><td>'left', 'right', 'top', 'bottom'</td><td><code>cblocation => 'left',</code></td></tr>
<tr><td><code>cborientation</code></td><td>None, or 'vertical', 'horizontal'</td><td></td></tr>
<tr><td><code>cbpad</code></td><td>fraction of the original axes between the image and the colorbar; the default 0.05 is often too big for a short, wide image</td><td><code>cbpad => 0.01,</code></td></tr>
<tr><td><code>cmap</code></td><td># The Colormap instance or registered colormap name used to map scalar data to colors.</td><td></td></tr>
<tr><td><code>colorbar_on</code></td><td>draw the colorbar; on by default, <code>0</code> turns it off</td><td><code>colorbar_on => 0</code></td></tr>
<tr><td><code>shared_colorbar</code></td><td>0-based indices of the subplots that should share one colorbar, and therefore one color scale</td><td><code>shared_colorbar => [0,1]</code></td></tr>
<tr><td><code>stringmap</code></td><td>a hash giving the meaning of each string used in <code>data</code>, which also makes string data legal</td><td><code>stringmap => { H => 'Alpha helix' }</code></td></tr>
<tr><td><code>vmax</code></td><td>float</td><td></td></tr>
<tr><td><code>vmin</code></td><td>float</td><td></td></tr>
</tbody>
</table>

=head3 single, simple plot

 my @imshow_data;
 foreach my $i (0..360) {
     foreach my $j (0..360) {
         push @{ $imshow_data[$i] }, sin($i * $pi/180)*cos($j * $pi/180);
     }
 }
 plt(
     data              => \@imshow_data,
     execute           => 0,
    fh => $fh,
     output_file => 'output.images/imshow.single.png',
     plot_type         => 'imshow',
     set_xlim          => '0, ' . scalar @imshow_data,
     set_ylim          => '0, ' . scalar @imshow_data,
 );

which makes the following image:


=for html
<p>
<img width="599" height="491" alt="imshow single" src="https://github.com/user-attachments/assets/3fa4ffe6-4817-4133-9c91-b68099400377" />
<p>


=head3 multiple plots

 plt(
     plots  => [
         {
             data => \@imshow_data,
             plot_type         => 'imshow',
             set_xlim          => '0, ' . scalar @imshow_data,
             set_ylim          => '0, ' . scalar @imshow_data,
             title             => 'basic',
         },
         {
             cblabel           => 'sin(x) * cos(x)',
             data => \@imshow_data,
             plot_type         => 'imshow',
             set_xlim          => '0, ' . scalar @imshow_data,
             set_ylim          => '0, ' . scalar @imshow_data,
             title             => 'cblabel',
         },
         {
             cblabel           => 'sin(x) * cos(x)',
             cblocation        => 'left',
             data              => \@imshow_data,
             plot_type         => 'imshow',
             set_xlim          => '0, ' . scalar @imshow_data,
             set_ylim          => '0, ' . scalar @imshow_data,
             title             => 'cblocation = left',
         },
         {
             cblabel           => 'sin(x) * cos(x)',
             data              => \@imshow_data,
             add               => [ # add secondary plots
             { # 1st additional plot
                 data              => {
                     'sin(x)'       => [
                         [0..360],
                         [map {180 + 180*sin($_ * $pi/180)} 0..360]
                     ],
                     'cos(x)'       => [
                         [0..360],
                         [map {180 + 180*cos($_ * $pi/180)} 0..360]
                     ],
                 },
                 plot_type => 'plot',
                 set_options => {
                     'sin(x)'    =>  'color = "red", linestyle = "dashed"',
                     'cos(x)'    =>  'color = "blue", linestyle = "dashed"',
                 }
             }
             ],
             plot_type         => 'imshow',
             set_xlim          => '0, ' . scalar @imshow_data,
             set_ylim          => '0, ' . scalar @imshow_data,
             title             => 'auxiliary plots',
         },
     ],
     execute         => 0,
   fh              => $fh,
     output_file     => 'output.images/imshow.multiple.png',
     ncols           => 2,
     nrows           => 2,
     set_figheight   => 6*3,# 4.8
     set_figwidth    => 6*4 # 6.4
 );

which makes the following image:


=for html
<p>
<img width="2416" height="1811" alt="imshow multiple" src="https://github.com/user-attachments/assets/091acccb-151c-47ca-82cc-99c19d2bff91" />
<p>


=head3 Secondary Structure Prediction (DSSP)

Sometimes strings instead of numbers can be entered into a 2-D array, one example is protein secondary structure.
Protein secondary structure can be plotted thus, with a key in C<stringmap> to show which strings become which integers in a minimal working example:

 plt(
     cbpad       => 0.01,          # default 0.05 is too big
     data        => [              # imshow gets a 2D array
         [' ', ' ', ' ', ' ', 'G'], # bottom
         ['S', 'I', 'T', 'E', 'H'], # top
     ],
     plot_type => 'imshow',
     stringmap   => {
         'H' => 'Alpha helix',
         'B' => 'Residue in isolated β-bridge',
         'E' => 'Extended strand, participates in β ladder',
         'G' => '3-helix (3/10 helix)',
         'I' => '5 helix (pi helix)',
         'T' => 'hydrogen bonded turn',
         'S' => 'bend',
         ' ' => 'Loops and irregular elements'
     },
     output_file => 'output.images/dssp.single.png',
     scalex        => 2.4,
     set_ylim      => '0, 1',
     title         => 'Dictionary of Secondary Structure in Proteins (DSSP)',
     xlabel        => 'xlabel',
     ylabel        => 'ylabel'
 );


=for html
<p>
<img width="1547" height="491" alt="dssp single" src="https://github.com/user-attachments/assets/712f6199-4a41-4d8f-953e-19df9dacc447" />
<p>


or for multiple plots, where the colorbar can be spread across multiple plots now:

 plt(
     cbpad       => 0.01,          # default 0.05 is too big
     plots       => [
         { # 1st plot
             data    => [
                 [' ', ' ', ' ', ' ', 'G'], # bottom
                 ['S', 'I', 'T', 'E', 'H'], # top
             ],
             plot_type => 'imshow',
             set_xticklabels=> '[]', # remove x-axis labels
             set_ylim    => '0, 1',
             stringmap   => {
                 'H' => 'Alpha helix',
                 'B' => 'Residue in isolated β-bridge',
                 'E' => 'Extended strand, participates in β ladder',
                 'G' => '3-helix (3/10 helix)',
                 'I' => '5 helix (pi helix)',
                 'T' => 'hydrogen bonded turn',
                 'S' => 'bend',
                 ' ' => 'Loops and irregular elements'
             },
             title         => 'top plot',
             ylabel        => 'ylabel'
         },
         { # 2nd plot
             data    => [
                 [' ', ' ', ' ', ' ', 'G'], # bottom
                 ['S', 'I', 'T', 'E', 'H'], # top
             ],
             plot_type => 'imshow',
             set_ylim    => '0, 1',
             stringmap   => {
                 'H' => 'Alpha helix',
                 'B' => 'Residue in isolated β-bridge',
                 'E' => 'Extended strand, participates in β ladder',
                 'G' => '3-helix (3/10 helix)',
                 'I' => '5 helix (pi helix)',
                 'T' => 'hydrogen bonded turn',
                 'S' => 'bend',
                 ' ' => 'Loops and irregular elements'
             },
             title         => 'bottom plot',
             xlabel        => 'xlabel',
             ylabel        => 'ylabel'
         }
     ],
     nrows             => 2,
     output_file       => 'output.images/dssp.multiple.png',
     scalex            => 2.4,
     shared_colorbar => [0,1], # plots 0 and 1 share a colorbar
     suptitle          => 'Dictionary of Secondary Structure in Proteins (DSSP)',
 );

which makes the following plot:


=for html
<p>
<img width="1547" height="491" alt="dssp multiple" src="https://github.com/user-attachments/assets/d88e295e-1d1e-4e2a-bd5b-48029c46f5b0" />
<p>


=head2 pie

Plot a hash of numbers as a pie chart: one wedge per key, sized by its share of
the total.  C<data> is the same simple hash that C<bar> takes, so the two are
interchangeable — reach for C<pie> when the reader should see parts of a whole,
and for C<bar> when they should compare the parts with each other.

Wedges are laid out in sorted key order unless C<key_order> says otherwise, and
a C<key_order> that names only some of the keys draws only those wedges.  No
legend is added — the wedges carry their own labels — so C<show_legend> is not
among the options C<pie> accepts.

=head3 options

=for html
<table>
<tbody>
<tr><td>Option</td><td>Description</td><td>Example</td></tr>
<tr><td>--------</td><td>-------</td><td>-------</td></tr>
<tr><td><code>autopct</code></td><td>a Python format string for the share printed inside each wedge; omit it and no numbers are drawn</td><td><code>autopct => '%1.1f%%'</code></td></tr>
<tr><td><code>key_order</code></td><td>array ref: the order the wedges are laid out in.  Naming only some of the keys draws only those wedges</td><td><code>key_order => ['Fri','Sat','Sun']</code></td></tr>
<tr><td><code>labeldistance</code></td><td>where the key label sits, as a fraction of the radius: <code>0</code> is the centre, <code>1</code> the edge, above <code>1</code> outside the pie</td><td><code>labeldistance => 0.6</code></td></tr>
<tr><td><code>pctdistance</code></td><td>the same scale, for the <code>autopct</code> text.  Swapping the two — labels in, percentages out — is a readable arrangement when the labels are long</td><td><code>pctdistance => 1.25</code></td></tr>
</tbody>
</table>

=head3 single, simple plot

 plt(
     output_file => 'output.images/single.pie.png',
     data              => {                                 # simple hash
         Fri => 76,
         Mon => 73,
         Sat => 26,
         Sun => 11,
         Thu => 94,
         Tue => 93,
         Wed => 77
     },
     plot_type    => 'pie',
     title        => 'Single Simple Pie',
     fh           => $fh,
     execute      => 0,
 );

which makes the image:


=for html
<p>
<img width="469" height="491" alt="single pie" src="https://github.com/user-attachments/assets/a0bc3212-d013-463a-9be6-f96829ac7dba" />
<p>


=head3 multiple plots

 plt(
     output_file => 'output.images/pie.png',
     plots             => [
         {
             data => {
                 'Russian' => 106_000_000,    # Primarily European Russia
                 'German'  =>
                   95_000_000,    # Germany, Austria, Switzerland, etc.
                 'English' => 70_000_000,      # UK, Ireland, etc.
                 'French' => 66_000_000, # France, Belgium, Switzerland, etc.
                 'Italian'   => 59_000_000,    # Italy, Switzerland, etc.
                 'Spanish'   => 45_000_000,    # Spain
                 'Polish'    => 38_000_000,    # Poland
                 'Ukrainian' => 32_000_000,    # Ukraine
                 'Romanian'  => 24_000_000,    # Romania, Moldova
                 'Dutch'     => 22_000_000     # Netherlands, Belgium
             },
             plot_type => 'pie',
             title       => 'Top Languages in Europe',
             suptitle    => 'Pie in subplots',
         },
         {
             data => {
                 'Russian' => 106_000_000,     # Primarily European Russia
                 'German'  =>
                   95_000_000,    # Germany, Austria, Switzerland, etc.
                 'English' => 70_000_000,      # UK, Ireland, etc.
                 'French' => 66_000_000, # France, Belgium, Switzerland, etc.
                 'Italian'   => 59_000_000,    # Italy, Switzerland, etc.
                 'Spanish'   => 45_000_000,    # Spain
                 'Polish'    => 38_000_000,    # Poland
                 'Ukrainian' => 32_000_000,    # Ukraine
                 'Romanian'  => 24_000_000,    # Romania, Moldova
                 'Dutch'     => 22_000_000     # Netherlands, Belgium
             },
             plot_type => 'pie',
             title       => 'Top Languages in Europe',
             autopct     => '%1.1f%%',
         },
         {
             data => {
                 'United States'  => 86,
                 'United Kingdom' => 33,
                 'Germany'        => 29,
                 'France'         => 10,
                 'Japan'          => 7,
                 'Israel'         => 6,
             },
             title         => 'Chem. Nobels: swap text positions',
             plot_type     => 'pie',
             autopct       => '%1.1f%%',
             pctdistance   => 1.25,
             labeldistance => 0.6,
         }
     ],
     fh => $fh,
     execute      => 0,
    set_figwidth  => 12,
     ncols        => 3,
 );


=for html
<p>
<img width="1210" height="444" alt="pie" src="https://github.com/user-attachments/assets/4c44d300-fd84-49bc-9a32-b73af54286cf" />
<p>


=head2 plot

A line plot of one or more series of C<(x, y)> points. Each series needs an
x array and a y array of B<equal length>, or, in the hash form, may give the y
values alone and have x made for it.

=head3 Entering data

C<data> accepts four shapes:

B<1. Labeled series (hash).> Use this when you want a legend — each key
becomes a line label. The value is a C<[ \@x, \@y ]> pair:

 {
     plot_type => 'plot',
     data        => {
         A => [ [5..9], [5..9] ],
         B => [ [5..9], [1..5] ],
     },
 }

B<2. Several unlabeled series (array of pairs).> A list of C<[ \@x, \@y ]>
pairs, one per line, with no legend labels:

 {
     plot_type => 'plot',
     data        => [
         [ [5..9], [5..9] ],
         [ [5..9], [1..5] ],
     ],
 }

B<3. A single unlabeled series (two bare arrays).> The simplest form: just
the x array and the y array, with no enclosing pair-array and no key:

 {
     plot_type => 'plot',
     data        => [
         [5..9],
         [5..9],
     ],
 }

Form 3 is shorthand for form 2 with a single line — it is promoted internally
to C<[ [ \@x, \@y ] ]>. Because there is no key, the line is B<unlabeled>; if
you need a legend entry, use the hash form (1).

 > How the forms are told apart: in the multi-line form (2) C<< data-E<gt>[0] >> is itself
 > a C<[ \@x, \@y ]> pair, so C<< data-E<gt>[0][0] >> is an array ref; in the single-line
 > form (3) C<< data-E<gt>[0] >> is the x array, so C<< data-E<gt>[0][0] >> is a number. A 2-element
 > C<data> whose first element starts with a number is therefore always read as a
 > single line.

B<4. Labeled y values alone (hash).> When the x values are only the positions
0, 1, 2, …, give each key a plain array of y values and leave x out:

 plt(
     output_file => 'output.images/plot.y.only.png',
     data        => {    # y values only: x is 0, 1, 2, ... for each
         '1cka' => [ 0.86, 0.85, 0.85, 0.85, 0.85 ],
         '1ckb' => [ 0.81, 0.8,  0.79, 0.78, 0.77 ],
         '1d4t' => [ 0.92, 0.92, 0.92, 0.92, 0.91 ],
     },
     plot_type  => 'plot',
     title      => 'y values only',
     xlabel     => 'index',
     ylabel     => 'score',
     set_xticks => '[0, 1, 2, 3, 4]',
 );

which makes


=for html
<p>
<img width="651" height="491" alt="plot of y values only" src="https://raw.githubusercontent.com/hhg7/MatPlotLib-Simple/main/output.images/plot.y.only.png" />
<p>


Each key's x is C<0 .. n-1> for its own C<n> values, so the series need not be the
same length. A key's value is read as y alone when B<none> of its elements is
an array, and as an C<[ \@x, \@y ]> pair when they all are; the two forms can be
mixed from key to key in one C<data> hash, but a value that mixes arrays with
plain numbers is refused. This form is for hash data only: in array data, two
plain arrays are already the single unlabeled line of form 3, with x and y.

=head3 Setting line options with C<set_options>

C<set_options> is passed straight through to Matplotlib's C<.plot(x, y, ...)>,
so anything C<plot> accepts works (C<color>, C<linewidth>, C<linestyle>, C<marker>,
C<alpha>, …). How you supply it depends on the data shape:

B<A scalar applies to every line.> This is the natural partner of the
single-line data form — the one option string is used for the only series:

 {
     plot_type     => 'plot',
     show_legend => 0,
     data          => [
         [ min(vals($df, 'experiment')) .. max(vals($df, 'experiment')) ],
         [ min(vals($df, 'experiment')) .. max(vals($df, 'experiment')) ],
     ],
     set_options => 'color = "red"',
 }

The same scalar also works with the multi-line array form, where it is applied
to B<all> lines at once:

 {
     plot_type     => 'plot',
     data          => [
         [ [5..9], [5..9] ],
         [ [5..9], [1..5] ],
     ],
     set_options => 'linewidth = 2',    # both lines
 }

B<An array sets options per line (positional).> With array data, give one
string per line; entry C<i> styles line C<i>. You may supply fewer entries than
lines, but not more:

 {
     plot_type     => 'plot',
     data          => [
         [ [5..9], [5..9] ],
         [ [5..9], [1..5] ],
     ],
     set_options => [
         'color = "red"',
         'color = "blue", linestyle = "--"',
     ],
 }

B<A hash sets options per key.> With hash data, key the options by the same
data keys (any key may be omitted):

 {
     plot_type     => 'plot',
     data          => {
         A => [ [5..9], [5..9] ],
         B => [ [5..9], [1..5] ],
     },
     set_options => {
         A => 'color = "red"',
         B => 'color = "blue", marker = "o"',
     },
 }

Note the pairing rule: a scalar C<set_options> goes with B<any> data shape; an
B<array> C<set_options> goes with B<array> data; a B<hash> C<set_options> goes
with B<hash> data. Mismatches (for example a hash of options with array data)
are rejected with an explanatory error.

=head3 Other options

=over

=item * C<show_legend> — on by default (C<1>); set to C<0> to suppress labels. Only the
hash form produces labels in the first place.

=item * C<key_order> — array of keys (hash form) fixing the draw/legend order; defaults
to the keys sorted alphabetically.

=item * C<logscale> — array of axes to put on a log scale, e.g. C<[ 'x', 'y' ]>.

=item * C<twinx> — draw selected series against a secondary y-axis.

=over

=item * hash data: a single key, or a hash whose keys are the series to twin;

=item * array data: an integer index, or an array of indices.

=back

=item * C<twinx_args> — a hash keyed by data key (hash form) or index (array form);
each value is a hash of axis options (e.g. C<ylabel>, C<set_ylim>) applied to
that twin axis.

=back

Common axes options such as C<title>, C<xlabel>, C<ylabel>, and C<legend> are
accepted here too, exactly as for the other plot types.

=head3 Two y-axes with C<twinx>

Series measured in different units, or on wildly different scales, flatten each
other when they share a y-axis.  C<twinx> moves the named series onto a second
y-axis on the right, and C<twinx_args> labels it:

 plt(
     output_file => '/tmp/twinx.svg',
     plot_type     => 'plot',
     data          => {
         Temperature => [ [@t], [@celsius] ],
         Pressure    => [ [@t], [@hPa]     ],
     },
     twinx         => 'Pressure',                        # onto the right axis
     twinx_args    => { Pressure => { ylabel => 'hPa' } },
     ylabel        => 'degrees C',                       # the left axis
     xlabel        => 'hour',
 );

C<< twinx =E<gt> 'Pressure' >> is shorthand for the single-series case.  To twin more than
one series, pass a hash whose keys are the series to move:

 twinx => { Pressure => 1, Humidity => 1 },

The twinned series share the one right-hand axis, so a C<twinx_args> of each
applies to that axis.  Every series, on either axis, is listed in the one
legend.  Up to 0.318 each twinned series had a right-hand axis of its own, with
limits of its own and its ticks drawn over the others', and none of them was in
the legend.

With array data the same options are given by index instead of by key:

 plt(
     output_file => '/tmp/twinx.arr.svg',
     plot_type     => 'plot',
     data          => [
         [ [@t], [@celsius] ],    # index 0, left axis
         [ [@t], [@hPa]     ],    # index 1
     ],
     twinx         => 1,                              # index 1 goes right
     twinx_args    => { 1 => { ylabel => 'hPa' } },
 );

An index past the last line is refused.

A C<plot> spec is an ordinary plot hash, so it can be dropped straight into the
L<#the-p-argument> argument — on its own for a single subplot, or alongside
other hashes to overlay or to fill a grid of subplots.

=head3 single, simple

data can be given as a hash, where the hash key is the label:

 plt(
     fh => $fh,
     execute           => 0,
     output_file => 'output.images/plot.single.png',
     data              => {
         'sin(x)' => [
             [@x],                     # x
             [ map { sin($_) } @x ]    # y
         ],
         'cos(x)' => [
             [@x],                     # x
             [ map { cos($_) } @x ]    # y
         ],
     },
     plot_type => 'plot',
     title       => 'simple plot',
     set_xticks  =>
     "[-2 * $pi, -3 * $pi / 2, -$pi, -$pi / 2, 0, $pi / 2, $pi, 3 * $pi / 2, 2 * $pi"
      . '], [r\'$-2\pi$\', r\'$-3\pi/2$\', r\'$-\pi$\', r\'$-\pi/2$\', r\'$0$\', r\'$\pi/2$\', r\'$\pi$\', r\'$3\pi/2$\', r\'$2\pi$\']',
     set_options => {    # set options overrides global settings
         'sin(x)' => 'color="blue", linewidth=2',
         'cos(x)' => 'color="red",  linewidth=2'
     }
 );

or as an array of arrays:

 plt(
     fh => $fh,
     execute           => 0,
     output_file => 'output.images/plot.single.arr.png',
     data              => [
         [
             [@x],                     # x
             [ map { sin($_) } @x ]    # y
         ],
         [
             [@x],                     # x
             [ map { cos($_) } @x ]    # y
         ],
     ],
     plot_type => 'plot',
     title       => 'simple plot',
     set_xticks  =>
     "[-2 * $pi, -3 * $pi / 2, -$pi, -$pi / 2, 0, $pi / 2, $pi, 3 * $pi / 2, 2 * $pi"
      . '], [r\'$-2\pi$\', r\'$-3\pi/2$\', r\'$-\pi$\', r\'$-\pi/2$\', r\'$0$\', r\'$\pi/2$\', r\'$\pi$\', r\'$3\pi/2$\', r\'$2\pi$\']',
     set_options => [    # set options overrides global settings; indices match data array
         'color="blue", linewidth=2, label = "sin(x)"', # labels aren't added automatically when using array here
         'color="red",  linewidth=2, label = "cos(x)"'
     ],
 );

both of which make the following "plot" plot:


=for html
<p>
<img width="651" height="491" alt="plot single" src="https://github.com/user-attachments/assets/6cbd6aad-c464-4703-b962-b420ec08bb66" />
<p>


=head3 multiple sub-plots

which makes

 my $epsilon = 10**-7;
 my (%set_opt, %d);
 my $i = 0;
 foreach my $interval (
     [-2*$pi, -$pi],
     [-$pi, 0],
     [0, $pi],
     [$pi, 2*$pi]
 ) {
     my @th = linspace($interval->[0] + $epsilon, $interval->[1] - $epsilon, 99, 0);
     @{ $d{csc}{$i}[0] } = @th;
     @{ $d{csc}{$i}[1] } = map { 1/sin($_) } @th;
     @{ $d{cot}{$i}[0] } = @th;
     @{ $d{cot}{$i}[1] } = map { cos($_)/sin($_) } @th;
     if ($i == 0) {
         $set_opt{csc}{$i} = 'color = "red", label = "csc(θ)"';
         $set_opt{cot}{$i} = 'color = "violet", label = "cot(θ)"';
     } else {
         $set_opt{csc}{$i} = 'color = "red"';
         $set_opt{cot}{$i} = 'color = "violet"';
     }
     $i++;
 }
 $i = 0;
 foreach my $interval (
     [-2 * $pi, -1.5 * $pi],
     [-1.5*$pi, -0.5*$pi],
     [-0.5*$pi, 0.5 * $pi],
     [0.5 * $pi, 1.5 * $pi],
     [1.5 * $pi, 2 * $pi]
 ) {
     my @th = linspace($interval->[0] + $epsilon, $interval->[1] - $epsilon, 99, 0);
     @{ $d{sec}{$i}[0] } = @th;
     @{ $d{sec}{$i}[1] } = map { 1/cos($_) } @th;
     if ($i == 0) {
         $set_opt{sec}{$i} = 'color = "blue", label = "sec(θ)"';
         $set_opt{tan}{$i} = 'color = "green", label = "tan(θ)"';
     } else {
         $set_opt{sec}{$i} = 'color = "blue"';
         $set_opt{tan}{$i} = 'color = "green"';
     }
     @{ $d{tan}{$i}[0] } = @th;
     @{ $d{tan}{$i}[1] } = map { sin($_)/cos($_) } @th;
     $i++;
 }
 mkdir 'svg' unless -d 'svg';
 my $xticks = "[-2 * $pi, -3 * $pi / 2, -$pi, -$pi / 2, 0, $pi / 2, $pi, 3 * $pi / 2, 2 * $pi"
         . '], [r\'$-2\pi$\', r\'$-3\pi/2$\', r\'$-\pi$\', r\'$-\pi/2$\', r\'$0$\', r\'$\pi/2$\', r\'$\pi$\', r\'$3\pi/2$\', r\'$2\pi$\']';
 my ($min, $max) = (-9,9);
 plt(
     fh => $fh,
     execute           => 0,
     output_file => 'output.images/plots.png',
     plots         => [
     { # sin
         data          => {
             'sin(θ)' => [
                 [@x],
                 [map {sin($_)} @x]
             ]
         },
         plot_type     => 'plot',
         set_options => {
             'sin(θ)' => 'color = "orange"'
         },
         set_xticks    => $xticks,
         set_xlim      => "-2*$pi, 2*$pi",
         xlabel        => 'θ',
         ylabel        => 'sin(θ)',
     },
     { # sin
         data          => {
             'cos(θ)' => [
                 [@x],
                 [map {cos($_)} @x]
             ]
         },
         plot_type     => 'plot',
         set_options => {
             'cos(θ)' => 'color = "black"'
         },
         set_xticks    => $xticks,
         set_xlim      => "-2*$pi, 2*$pi",
         xlabel        => 'θ',
         ylabel        => 'cos(θ)',
     },
     { # csc
         data          => $d{csc},
         plot_type     => 'plot',
         set_options => $set_opt{csc},
         set_xticks    => $xticks,
         set_xlim      => "-2*$pi, 2*$pi",
         set_ylim      => "$min,$max",
         show_legend => 0,
         vlines        => [ # asymptotes
             "-2*$pi, $min, $max, color = 'gray', linestyle = 'dashed'",
             "-$pi, $min, $max, color = 'gray', linestyle = 'dashed'",
             "0, $min, $max, color = 'gray', linestyle = 'dashed'",
             "$pi, $min, $max, color = 'gray', linestyle = 'dashed'",
             "2*$pi, $min, $max, color = 'gray', linestyle = 'dashed'",
         ],
         xlabel        => 'θ',
         ylabel        => 'csc(θ)',
     },
     { # sec
         data          => $d{sec},
         plot_type     => 'plot',
         set_options => $set_opt{sec},
         set_xticks    => $xticks,
         set_xlim      => "-2*$pi, 2*$pi",
         set_ylim      => "$min,$max",
         show_legend => 0,
         vlines        => [ # asymptotes
             "-1.5*$pi, $min, $max, color = 'gray', linestyle = 'dashed'",
             "-.5*$pi, $min, $max, color = 'gray', linestyle = 'dashed'",
             ".5*$pi, $min, $max, color = 'gray', linestyle = 'dashed'",
             "1.5*$pi, $min, $max, color = 'gray', linestyle = 'dashed'",
 #           "2*$pi, $min, $max, color = 'gray', linestyle = 'dashed'",
         ],
         xlabel        => 'θ',
         ylabel        => 'sec(θ)',
     },
         { # csc
         data          => $d{cot},
         plot_type     => 'plot',
         set_options => $set_opt{cot},
         set_xticks    => $xticks,
         set_xlim      => "-2*$pi, 2*$pi",
         set_ylim      => "$min,$max",
         show_legend => 0,
         vlines        => [ # asymptotes
             "-2*$pi, $min, $max, color = 'gray', linestyle = 'dashed'",
             "-$pi, $min, $max, color = 'gray', linestyle = 'dashed'",
             "0, $min, $max, color = 'gray', linestyle = 'dashed'",
             "$pi, $min, $max, color = 'gray', linestyle = 'dashed'",
             "2*$pi, $min, $max, color = 'gray', linestyle = 'dashed'",
         ],
         xlabel        => 'θ',
         ylabel        => 'cot(θ)',
     },
     { # sec
         data          => $d{tan},
         plot_type     => 'plot',
         set_options => $set_opt{tan},
         set_xticks    => $xticks,
         set_xlim      => "-2*$pi, 2*$pi",
         set_ylim      => "$min,$max",
         show_legend => 0,
         vlines        => [ # asymptotes
             "-1.5*$pi, $min, $max, color = 'gray', linestyle = 'dashed'",
             "-.5*$pi, $min, $max, color = 'gray', linestyle = 'dashed'",
             ".5*$pi, $min, $max, color = 'gray', linestyle = 'dashed'",
             "1.5*$pi, $min, $max, color = 'gray', linestyle = 'dashed'",
 #           "2*$pi, $min, $max, color = 'gray', linestyle = 'dashed'",
         ],
         xlabel        => 'θ',
         ylabel        => 'tan(θ)',
     },
     ], # end
     ncols        => 2,
     nrows        => 3,
     set_figwidth => 8,
     suptitle     => 'Basic Trigonometric Functions'
 );


=for html
<p>
<img width="811" height="491" alt="plots" src="https://github.com/user-attachments/assets/0bdd0744-c1bb-4c4a-9482-b3de3f2d4fc2" />
<p>


=head2 scatter

Plot points from a hash of arrays.  Beyond x and y, a scatterplot can carry a
third number per point as B<color>, which is where most of C<scatter>'s options
go.

=head3 Entering data

C<data> takes three shapes, and which one you passed is worked out from whether the
values are arrays or hashes.

B<1. One set (hash of 2 or 3 array refs).> All the arrays must be the same
length.  Keys are taken in case-insensitive sorted order: the first is x, the
second y, and a third — if present — is the value each point is colored by, which
also gets a colorbar.  Exactly 2 or 3 keys are allowed; anything else is an
error.  The keys become the axis labels, so naming them for the quantity they
hold pays off:

 scatter(
     output_file => '/tmp/scatter.svg',
     data          => {
         Height => \@height,    # x
         Weight => \@weight,    # y
         Age    => \@age,       # colour + colorbar
     },
     color_key     => 'Age',    # say so rather than relying on the sort
     cmap          => 'viridis',
 );

Sorted order is convenient but fragile — rename a key and the axes swap.  Use
C<keys> to fix the roles positionally, or C<color_key> to name the color column
explicitly, as above:

     keys => [ 'Weight', 'Height', 'Age' ],    # x, y, colour

B<2. Several labelled sets (hash of hashes of array refs).> The outer key is
the set's legend label; each inner hash is a set of 2 or 3 arrays read exactly as
in form 1.  This is the form to use for "the same measurement, split by group":

 scatter(
     output_file => '/tmp/by.group.svg',
     data          => {
         Male   => { Height => \@mh, Weight => \@mw },
         Female => { Height => \@fh, Weight => \@fw },
     },
     set_options => {
         Male   => 'marker = "v", color = "blue"',
         Female => 'marker = "o", color = "red"',
     },
 );

With three inner keys, every set is colored by its own third column, on one
scale running from the smallest to the largest color value of all the sets, and
the figure gets a single colorbar for that scale.  A set whose C<set_options>
give their own C<vmin>, C<vmax> or C<norm> keeps them instead.  Since color then says nothing about which set a point belongs to, each such set is drawn with its own marker -- C<o>, C<s>, C<^>, C<D>, C<v> and on, in the sorted order of the set names -- unless its C<set_options> name a C<marker>, which no other set is then given.  C<color_key>
then names an B<inner> key, and it must exist in every set: naming a key that is
not there is an error rather than being quietly ignored.

B<3. One point per set (hash of hashes of numbers).> An inner hash whose values
are all plain numbers is a single point, read as in form 2 and labelled with the
set's name in the legend.  This suits one summary per group, such as the scores
of several models:

 scatter(
     output_file => '/tmp/models.svg',
     data          => {
         catboost   => { MAE => 0.41, MSE => 0.30, R2 => 0.83 },
         elasticnet => { MAE => 0.60, MSE => 0.55, R2 => 0.61 },
     },
     keys          => [ 'MAE', 'R2', 'MSE' ],    # x, y, colour
 );

A set cannot mix the two: numbers for some keys and arrays for others is an
error.

=head3 options

=for html
<table>
<tbody>
<tr><td>Option</td><td>Description</td><td>Example</td></tr>
<tr><td>--------</td><td>-------</td><td>-------</td></tr>
<tr><td><code>cmap</code></td><td>the colormap used when a third key colors the points; <code>gist_rainbow</code> by default</td><td><code>cmap => 'viridis'</code></td></tr>
<tr><td><code>color_key</code></td><td>which key of <code>data</code> holds the color values, rather than letting the sort decide.  For the multi-set form this is an inner key, and it must be present in every set</td><td><code>color_key => 'Age'</code></td></tr>
<tr><td><code>colorbar_on</code>, <code>cblabel</code> and the other colorbar options</td><td>the colorbar drawn when a third key colors the points, as listed under Color Bars; <code>cblabel</code> defaults to the color key's name, and <code>colorbar_on => 0</code> leaves the colorbar out</td><td><code>cblabel => 'Age (years)'</code></td></tr>
<tr><td><code>key_order</code></td><td>the multi-set form only: the order the sets are drawn in, and so of the legend and of the markers each is given; sorted by name by default</td><td><code>key_order => ['catboost', 'xgboost']</code></td></tr>
<tr><td><code>keys</code></td><td>array ref fixing the roles of the keys positionally: x, y, then color.  In either form, the single-set or the multi-set, naming only x and y of three keys leaves the third as the color</td><td><code>keys => ['Weight', 'Height', 'Age']</code></td></tr>
<tr><td><code>logscale</code></td><td>an array of the axes to put on a log scale</td><td><code>logscale => ['x', 'y']</code></td></tr>
<tr><td><code>set_options</code></td><td>arguments passed straight to Matplotlib's <code>ax.scatter</code>: <code>marker</code>, <code>color</code>, <code>alpha</code>, <code>s</code>, …  A **scalar** for the single-set form; a **hash keyed by set name** for the multi-set form; the other shape is refused.  Options for a set that has no data are an error.  A <code>label</code> here replaces the set's name in the legend</td><td><code>set_options => 'marker = "v", alpha = 0.4'</code></td></tr>
<tr><td><code>show_legend</code></td><td>the multi-set form only: label each set with its name, for the legend; on by default</td><td><code>show_legend => 0</code></td></tr>
</tbody>
</table>

x, y and the color key of a set must hold the same number of values; a set that
does not is refused, naming its axes and their lengths.

C<xlabel> and C<ylabel> default to the names of the keys used for x and y; set them
explicitly to override.  The colorbar is labelled with the name of the color key
itself, and takes C<cbdrawedges> and C<cbpad> from
L<#color-bars-colorbars>.

=head3 single, simple plot

 scatter(
     fh            => $fh,
     data          => {
         X => [@x],
         Y => [map {sin($_)} @x]
     },
     execute       => 0,
     output_file => 'output.images/single.scatter.png',
 );

makes the following image:


=for html
<p>
<img width="651" height="491" alt="single scatter" src="https://github.com/user-attachments/assets/c45d9922-23e0-4f85-8306-aa7fca400328" />
<p>


=head3 options

=head3 multiple plots

 plt(
     fh => $fh,
     output_file => 'output.images/scatterplots.png',
     execute           => 0,
     nrows             => 2,
     ncols             => 3,
     set_figheight     => 8,
     set_figwidth      => 16,
     suptitle          => 'Scatterplot Examples',            # applies to all
     plots             => [
         {    # single-set scatter; no label
             data => {
                 X => @e,    # x-axis
                 Y => @b,    # y-axis
                 Z => @a     # color
             },
             title     => '"Single Set Scatterplot: Random Distributions"',
             color_key => 'Z',
             set_options => 'marker = "v"'
             , # arguments to ax.scatter: there's only 1 set, so "set_options" is a scalar
             text        => [ '100, 100, "text1"', '100, 100, "text2"', ],
             plot_type => 'scatter',
         },
         {     # multiple-set scatter, labels are "X" and "Y"
             data => {
                 X => {    # 1st data set; label is "X"
                     A => @a,    # x-axis
                     B => @b,    # y-axis
                 },
                 W => {    # 2nd data set; label is "Y"
                     A => generate_normal_dist( 100, 15, 210 ),    # x-axis
                     B => generate_normal_dist( 100, 15, 210 ),    # y-axis
                 }
             },
             plot_type     => 'scatter',
             title         => 'Multiple Set Scatterplot',
             set_options =>
             {    # arguments to ax.scatter, for each set in data
               X => 'marker = ".", color = "red"',
               W => 'marker = "d", color = "green"'
             },
         },
         {          # multiple-set scatter, labels are "X" and "Y"
             data => {    # 8th plot,
                 X => {    # 1st data set; label is "X"
                     A => @e,    # x-axis
                     B => @b,    # y-axis
                     C => @a,    # color
                 },
                 Y => {    # 2nd data set; label is "Y"
                     A => generate_normal_dist( 100, 15, 210 ),    # x-axis
                     B => generate_normal_dist( 100, 15, 210 ),    # y-axis
                     C => generate_normal_dist( 100, 15, 210 ),    # color
                 },
             },
             plot_type     => 'scatter',
             title         => 'Multiple Set Scatter w/ colorbar',
             set_options => {    # arguments to ax.scatter, for each set in data
                 X => 'marker = "."',    # point
                 Y => 'marker = "d"'     # diamond
             },
             color_key => 'C', # an inner key, present in both sets
         }
     ]
 );

which makes the following figure:


=for html
<p>
<img width="1610" height="461" alt="scatterplots" src="https://github.com/user-attachments/assets/b8a90f9f-acb3-4cf2-a423-6ad18686ab8c" />
<p>


=head2 venn_proportional_area

Draw an area-proportional Venn diagram, where the size of each region is scaled
to the number of elements it contains.  This plot type wraps the
LL<https://pypi.org/project/matplotlib-venn/> library, so that
library must be installed in addition to C<matplotlib>:

 python3 -m pip install matplotlib-venn

C<data> is a hash of array references; each key is a B<set> and its array is the
set's members (duplicates within a set are collapsed, exactly like a
mathematical set).  Because C<matplotlib_venn> only draws proportional-area
diagrams for two or three sets, C<data> must contain either B<2 or 3> keys.  By
default the sets are labelled and ordered alphabetically by key; use C<key_order>
to override that.

=head3 options

=for html
<table>
<tbody>
<tr><td>Option</td><td>Description</td><td>Example</td></tr>
<tr><td>--------</td><td>-------</td><td>-------</td></tr>
<tr><td><code>alpha</code></td><td>opacity of the set regions, <code>0</code>–<code>1</code> (default <code>0.4</code>)</td><td><code>alpha => 0.5</code></td></tr>
<tr><td><code>key_order</code></td><td>array ref giving the order (and hence label positions) of the sets; each set exactly once</td><td><code>key_order => ['Right','Left']</code></td></tr>
<tr><td><code>set_colors</code></td><td>array ref of colors, one per set, and so of the same length as <code>data</code></td><td><code>set_colors => [qw(skyblue lightgreen salmon)]</code></td></tr>
<tr><td><code>title</code></td><td>the subplot title</td><td><code>title => 'Gospels vs. Synoptics'</code></td></tr>
</tbody>
</table>

=head3 single, simple plot

C<venn_proportional_area> is a single-plot wrapper around C<plt>, so it can be
called directly:

 venn_proportional_area(
     output_file => 'output.images/single.venn.png',
     title         => 'Gospels vs. Synoptics',
     data          => {
         Gospels  => [qw(Matthew Mark Luke John)],
         Synoptic => [qw(Matthew Mark Luke)],
     },
 );

which makes the image:


=for html
<p>
<img width="467" height="491" alt="single venn" src="https://raw.githubusercontent.com/hhg7/MatPlotLib-Simple/main/output.images/single.venn.png" />
<p>


=head3 multiple plots

Like every other plot type, it can also be one panel among several via C<plt>
and the C<plots> array; here a two-set diagram sits beside a colored three-set
diagram:

 plt(
     output_file => 'output.images/venn.png',
     ncols         => 2,
     suptitle      => 'Proportional-area Venn diagrams',
     plots => [
         {
             plot_type => 'venn_proportional_area',
             title       => 'Two sets',
             data        => {
                 Perl   => [qw(regex hashes CPAN sigils)],
                 Python => [qw(regex hashes pip indentation)],
             },
         },
         {
             plot_type    => 'venn_proportional_area',
             title        => 'Three sets with colors',
             set_colors   => [qw(skyblue lightgreen salmon)],
             alpha        => 0.5,
             data         => {
                 Mammals => [qw(bat whale dog cat human platypus)],
                 Aquatic => [qw(whale shark octopus platypus)],
                 Legged  => [qw(dog cat human bat platypus shark)],
             },
         },
     ],
 );

which makes the following figure:


=for html
<p>
<img width="651" height="409" alt="venn diagrams" src="https://raw.githubusercontent.com/hhg7/MatPlotLib-Simple/main/output.images/venn.png" />
<p>


=head2 violin

Plot a hash of array refs as violins: one kernel-density silhouette per key, with
the quartile box, the whiskers and a red dot at the mean drawn over it.  Where a
boxplot summarises a distribution in five numbers, a violin shows its shape, so
bimodal data that a boxplot would hide is visible.

C<violin> and C<violinplot> are the same subroutine under two names, and both
accept the two data shapes described under L<#boxplot> — a hash of array
refs, or a bare array ref for a single violin.  Non-numeric and undefined values
are dropped silently.  Each x-axis label carries the number of points that went
into it, so a violin drawn from very few points announces itself.

=head3 options

=for html
<table>
<tbody>
<tr><td>Option</td><td>Description</td><td>Example</td></tr>
<tr><td>--------</td><td>-------</td><td>-------</td></tr>
<tr><td><code>color</code></td><td>a single color for every violin</td><td><code>color => 'red'</code></td></tr>
<tr><td><code>colors</code></td><td>a hash pairing each data key with its own color; every key in <code>data</code> must appear</td><td><code>colors       => { E => 'yellow', B => 'purple', A => 'green' }</code></td></tr>
<tr><td><code>edgecolor</code></td><td>the color of the outline of every violin; <code>black</code> by default</td><td><code>edgecolor => 'none'</code></td></tr>
<tr><td><code>key_order</code></td><td>determine key order display on x-axis</td><td><code>key_order => ['B', 'A', 'E']</code></td></tr>
<tr><td><code>logscale</code></td><td>an array of the axes to put on a log scale; only <code>x</code> and <code>y</code> are accepted.  Note this is an array reference, not the <code>log => 1</code> scalar that <code>bar</code> takes</td><td><code>logscale => ['y']</code></td></tr>
<tr><td><code>orientation</code></td><td>'vertical', 'horizontal'}, default: 'vertical'</td><td><code>orientation => 'horizontal'</code></td></tr>
<tr><td><code>medians</code></td><td>draw a line at each median; on by default, <code>0</code> or <code>'False'</code> for off</td><td><code>medians => 0</code></td></tr>
<tr><td><code>whiskers</code></td><td>draw the quartile bar and whiskers over the silhouette; on by default, <code>0</code> leaves the bare violin</td><td><code>whiskers => 0</code></td></tr>
</tbody>
</table>

=head3 single, simple plot

 plt(
     output_file => 'output.images/single.violinplot.png',
     data              => {                                     # simple hash
         A => [ 55, @{$z} ],
         E => [ @{$y} ],
         B => [ 122, @{$z} ],
     },
     plot_type    => 'violinplot',
     title        => 'Single Violin Plot: Specified Colors',
     colors       => { E => 'yellow', B => 'purple', A => 'green' },
     fh => $fh,
     execute      => 0,
 );

which makes:


=for html
<p>
<img width="651" height="491" alt="single violinplot" src="https://github.com/user-attachments/assets/989650fd-c947-45b0-91c8-c7f71c075cf3" />
<p>


=head3 multiple plots

 plt(
     fh                => $fh,
     execute           => 0,
     output_file       => 'output.images/violin.png',
     plots             => [
         {
             data => {
                 E => @e,
                 B => @b
             },
             plot_type    => 'violinplot',
             title        => 'Basic',
             xlabel       => 'xlabel',
             set_figwidth => 12,
             suptitle     => 'Violinplot'
         },
         {
             data => {
                 E => @e,
                 B => @b
             },
             plot_type => 'violinplot',
             color       => 'red',
             title       => 'Set Same Color for All',
         },
         {
             data => {
                 E => @e,
                 B => @b
             },
             plot_type => 'violinplot',
             colors      => {
                 E => 'yellow',
                 B => 'black'
             },
             title => 'Color by Key',
         },
         {
             data => {
                 E => @e,
                 B => @b
             },
             orientation => 'horizontal',
             plot_type => 'violinplot',
             colors      => {
                 E => 'yellow',
                 B => 'black'
             },
             title => 'Horizontal orientation',
         },
         {
             data => {
                 E => @e,
                 B => @b
             },
             whiskers    => 0,
             plot_type => 'violinplot',
             colors      => {
                 E => 'yellow',
                 B => 'black'
             },
             title => 'Whiskers off',
         },
     ],
     ncols => 3,
     nrows => 2,
 );


=for html
<p>
<img width="1211" height="491" alt="violin" src="https://github.com/user-attachments/assets/248df5e4-fd57-45d6-96da-956af0a7dbfb" />
<p>


=head2 wide

Summarise B<several runs of the same curve>.  Every run is drawn as a faint
line, the mean of the runs as a solid one, and one standard deviation either side
of the mean as a translucent ribbon.  This is the plot for repeated measurements
— replicate experiments, repeated simulations, one trace per subject — where a
C<plot> of every line on top of the others would be an unreadable thicket and a
C<plot> of the mean alone would hide how much the runs disagree.

The runs do not have to share an x grid: each group's runs are interpolated onto
101 evenly spaced points spanning that group's own x range before the mean and
the standard deviation are taken, so runs of different lengths, or sampled at
different x values, can be summarised together.  A run is first sorted by x, so
it may be entered in any order; and it counts towards the mean and the ribbon
only between its own first and last x, so a run that stops early narrows the
summary to the runs that continue rather than being held flat at its last
value.

=head3 Entering data

B<1. Labelled groups (hash).> Each key is a group and becomes the legend label;
its value is an array of runs, and each run is a C<[ \@x, \@y ]> pair — the same
pair L<#plot> uses:

 my @x = 0 .. 100;
 my %runs;
 foreach my $group ('Clinical', 'HGI') {
     my $shift = $group eq 'HGI' ? 1 : 0;
     foreach my $replicate (1 .. 3) {
         push @{ $runs{$group} }, [
             [@x],                                                       # x
             [ map { $shift + sin($_/10) + rand_between(-0.2, 0.2) } @x ] # y
         ];
     }
 }
 wide(
     output_file => 'output.images/single.wide.png',
     data          => \%runs,
     color         => {          # one color per group
         Clinical => 'blue',
         HGI      => 'green',
     },
     title         => 'Visualization of similar lines plotted together',
     xlabel        => 'time',
     ylabel        => 'signal',
 );

which makes the image:


=for html
<p>
<img width="651" height="491" alt="wide single" src="https://raw.githubusercontent.com/hhg7/MatPlotLib-Simple/main/output.images/single.wide.png" />
<p>


B<2. One unlabelled group (array).> Drop the enclosing hash and pass one group's
array of runs directly; C<color> is then a single color rather than a hash:

 wide(
     output_file => 'output.images/single.array.png',
     data          => $runs{Clinical},
     color         => 'red',
 );

A group with a single run is legal — it just produces a line with a
zero-width ribbon — which is convenient when one group has replicates and
another does not.

=head3 options

=for html
<table>
<tbody>
<tr><td>Option</td><td>Description</td><td>Example</td></tr>
<tr><td>--------</td><td>-------</td><td>-------</td></tr>
<tr><td><code>color</code></td><td>for hash data, a hash of one color per group; for array data, a single color.  Groups with no entry take the next color of Matplotlib's default cycle (<code>C0</code>, <code>C1</code>, ...), in the sorted order of the group names, so a partial hash is allowed; before version 0.315 they were all <code>b</code> (blue)</td><td><code>color => { Clinical => 'blue', HGI => 'green' }</code></td></tr>
<tr><td><code>show_legend</code></td><td>on by default, and only the hash form has labels to show; <code>0</code> suppresses it</td><td><code>show_legend => 0</code></td></tr>
</tbody>
</table>

C<wide> accepts the usual axes options — C<title>, C<xlabel>, C<ylabel>, C<set_xlim>
and the rest — but B<not> C<logscale> or C<key_order>.  For a log axis use
Matplotlib's own C<< set_yscale =E<gt> '"log"' >>.  There is no C<key_order>: as of
version 0.315 the groups are drawn, and listed in the legend, in the sorted
order of their names, so the same data draws the same picture every time.
Before that they were drawn in Perl's hash order, which differs between runs.

=head3 single, simple plot

Both calls above go through the C<wide> wrapper; naming the type explicitly to
C<plt> is equivalent and takes exactly the same options:

 plt(
     output_file => 'output.images/single.wide.png',
     plot_type     => 'wide',
     data          => \%runs,
     color         => { Clinical => 'blue', HGI => 'green' },
 );

=head3 multiple plots

As an element of C<plots>, a C<wide> panel is just another plot hash — here the
labelled groups sit beside one group on its own:

 plt(
     output_file => 'output.images/wide.png',
     ncols         => 2,
     suptitle      => 'Replicate runs, summarised',
     plots         => [
         {
             plot_type => 'wide',
             data        => \%runs,               # hash of groups of runs
             color       => { Clinical => 'blue', HGI => 'green' },
             title       => '"Two groups, mean +/- 1 s.d."', # comma: quoted
             xlabel      => 'time',
             ylabel      => 'signal',
         },
         {
             plot_type     => 'wide',
             data          => $runs{Clinical},    # just the runs, unlabelled
             color         => 'red',
             show_legend => 0,
             title         => 'One group with no legend',
         },
     ],
 );


=for html
<p>
<img width="651" height="491" alt="wide subplots" src="https://raw.githubusercontent.com/hhg7/MatPlotLib-Simple/main/output.images/wide.png" />
<p>


Because a C<wide> panel collapses many lines into one summary, it also composes
well with a plot type that shows the same data another way.  Here the runs are
summarised on the left and the distribution of their final values is drawn beside
them:

 my %endpoints;
 foreach my $group (keys %runs) {
     @{ $endpoints{$group} } = map { $_->[1][-1] } @{ $runs{$group} };
 }
 plt(
     output_file => 'output.images/wide.and.violin.png',
     ncols         => 2,
     plots         => [
         {
             plot_type => 'wide',
             data        => \%runs,
             color       => { Clinical => 'blue', HGI => 'green' },
             title       => 'Runs over time',
         },
         {
             plot_type => 'violinplot',
             data        => \%endpoints,    # hash of arrays, same keys
             colors      => { Clinical => 'blue', HGI => 'green' },
             title       => 'Final values',
         },
     ],
 );


=for html
<p>
<img width="651" height="491" alt="wide and violin" src="https://raw.githubusercontent.com/hhg7/MatPlotLib-Simple/main/output.images/wide.and.violin.png" />
<p>


The three images above are written by C<wide.example.pl> in the git repository
(it is not shipped in the CPAN distribution); re-run it from the repository root
with C<perl -Ilib wide.example.pl> to regenerate them.

=head1 Advanced

=head2 Notes in Files

all files that can have notes with them, give notes about how the file was written.  For example, SVG files have the following:

 <dc:title>made/written by /mnt/ceph/dcondon/ui/gromacs/tut/dup.2puy/1.plot.gromacs.pl called using "plot" in /mnt/ceph/dcondon/perl5/perlbrew/perls/perl-5.42.0/lib/site_perl/5.42.0/x86_64-linux/Matplotlib/Simple.pm version 0.318 with Perl 5.42.0, Python 3.12.3, matplotlib 3.10.7</dc:title>

The Perl version is the one that wrote the script; the Python and matplotlib
versions are the ones that ran it, read by the script itself, so they are right
even when a script written with C<< execute =E<gt> 0 >> is run later or elsewhere.

=head2 Speed

To improve speed, all data can be written into a single temp python3 file thus:

 use File::Spec;
 use File::Temp;
 my $fh = File::Temp->new( DIR => File::Spec->tmpdir, SUFFIX => '.py', UNLINK => 0 );

all files will be written to C<< $fh-E<gt>filename >>; be sure to put C<< execute =E<gt> 0 >> unless you want the file to be run, which is the last step.

 plt(
     data => {
         Clinical => [
             [
                 [@xw],    # x
                 [@y]      # y
             ],
             [ [@xw], [ map { $_ + rand_between( -0.5, 0.5 ) } @y ] ],
             [ [@xw], [ map { $_ + rand_between( -0.5, 0.5 ) } @y ] ]
         ],
         HGI => [
             [
                 [@xw],                            # x
                 [ map { 1.9 - 1.1 / $_ } @xw ]    # y
             ],
             [ [@xw], [ map { $_ + rand_between( -0.5, 0.5 ) } @y ] ],
             [ [@xw], [ map { $_ + rand_between( -0.5, 0.5 ) } @y ] ]
         ]
     },
     output_file => 'output.images/single.wide.png',
     plot_type         => 'wide',
     color             => {
         Clinical => 'blue',
         HGI      => 'green'
     },
     title        => 'Visualization of similar lines plotted together',
     fh => $fh,
     execute      => 0,
 );
 # the last plot should have C<< execute =E<gt> 1 >>
 plt(
     data => [
         [
             [@xw],    # x
             [@y]      # y
         ],
         [ [@xw], [ map { $_ + rand_between( -0.5, 0.5 ) } @y ] ],
         [ [@xw], [ map { $_ + rand_between( -0.5, 0.5 ) } @y ] ]
     ],
     output_file => 'output.images/single.array.png',
     plot_type         => 'wide',
     color             => 'red',
     title             => 'Visualization of similar lines plotted together',
     fh                => $fh,
     execute           => 1,
 );

=head1 COPYRIGHT AND LICENSE

This software is free.  It is licensed under the same terms as Perl itself

=head1 Thanks

A lot of this work used Claude AI, which was paid for by the University of Idaho's IMCI
