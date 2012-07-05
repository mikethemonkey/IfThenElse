/*
 * Copyright 2011-2012  Martijn Koedam <qball@gmpclient.org>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of
 * the License.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

using GLib;

/**
 * IfThenElse is a simple program used to glue small unix tools to getter
 * with the ultimate goal to automate some tedious tasks.
 *
 * The structure off an IfThenElse chain matches that off a flow chart:
 * Trigger -> Check -> [Then] Action1 | [Else] Action2.<<BR>>
 * TODO: add nice ascii art picture here.
 *
 * For example a chain could be:
 *
 *  * Trigger: Every minute<<BR>>
 *  * Check:   Is a Movie Playing<<BR>>
 *  * Then:    Turn off the light<<BR>>
 *  * Else:    Turn on the light<<BR>>
 *
 * This should result the light turning off when starting the movie, and on
 * when the movie is finished.
 *
 * Each IfThenElse chain is an action in itself and can be chained up.
 *
 * =File format=
 *
 * A chain is described in it own file using the KeyFile format.
 * The parser used is the one provided with GLib, {@link GKeyFile}
 *
 * The format used in the KeyFile is very similar to the used on windows,
 * with the following differences:
 *
 *  * .ini files use the ';' character to begin comments, key files use the '#' character.
 *  * Key files do not allow for ungrouped keys meaning only comments can precede the first group.
 *  * Key files are always encoded in UTF-8.
 *  * Key and Group names are case-sensitive, for example a group called [GROUP] is a different group from [group].
 *  * .ini files don't have a strongly typed boolean entry type, they only have GetProfileInt. In GKeyFile only true and false (in lower case) are allowed.
 *
 * ==Example==
 *
 * The above mentioned chain could be described with the following example:
 *
 * {{{
 * [Trigger]
 * type=TimerTrigger
 * timeout=60
 * action=Check
 *
 * [Check]
 * type=ExternalToolCheck
 * cmd=check_movies.sh
 * true_status=1
 * false_status=0
 * compare_old_state=true
 * then_action=Then
 * else_action=Else
 *
 * [Then]
 * type=ExternalToolAction
 * cmd=switch_off_lights.sh
 *
 * [Else]
 * type=ExternalToolAction
 * cmd=switch_on_lights.sh
 * }}}
 *
 *
 * As you can see in the previous example, IfThenElse ties external tools together.
 * A IfThenElse chain can be seen as a flowchart.
 *
 *
 * ==Extending the example==
 *
 * Each 'node' in the chain can only have one input and one output connected to each 'port'.
 * So a trigger can only drive one next node, and visa versa.
 *
 * If you want to use multiple triggers, or drive multiple actions you have to use one of the
 * special nodes.
 * The {@link MultiCombine} node combines the different inputs, the {@link MultiAction}
 * drives multiple outputs.
 *
 * An example that uses the {@link MultiAction}:
 * Say that, in the previous example, we want to turn_off the lights and put gajim in offline mode:
 *
 * {{{
 * [Trigger]
 * type=TimerTrigger
 * timeout=60
 * action=Check
 *
 * [Check]
 * type=ExternalToolCheck
 * cmd=check_movies.sh
 * true_status=1
 * false_status=0
 * compare_old_state=true
 * then_action=ThenMulti
 * else_action=Else
 *
 * [ThenMulti]
 * type=MultiAction
 * action=Then1;Then2
 *
 * [Then1]
 * type=ExternalToolAction
 * cmd=switch_off_lights.sh
 *
 * [Then2]
 * type=ExternalToolAction
 * cmd=gajim-remote change_status offline
 *
 * [Else]
 * type=ExternalToolAction
 * cmd=switch_on_lights.sh
 * }}}
 *
 * This way, it is easy to make complex chains.
 *
 * =Using the program=
 *
 * IfThenElse takes a keyfile describing the chain as input.
 *
 * To run the program:
 * {{{
 * 		ifthenelse <list of input files>
 * }}}
 *
 * If you want to background IfThenElse.
 * {{{
 * 		ifthenelse -b <list of intput files>
 * }}}
 *
 * If you want to generate a flow chart from the chain:
 * {{{
 * 		ifthenelse -d output.dot <list of intput files>
 * }}}
 *
 * The generated dot file can be converted into an actual chart by
 * running do on it:
 * {{{
 * 		dot -Tpng -O output.dot
 * }}}
 * This will generate a output.dot.png
 *
 * ==Accepted inputfiles==
 *
 * IfThenElse accepts both individual files as input as directories.
 * If a directory is passed it will, recursively, scan that directory for .ife files.
 *
 * If no input file is given, it will load the .ife files in the ~/.IfThenElse directory.
 *
 * ==Accepted Signals==
 *
 * IfThenElse accepts the following signals:
 *
 *  * INT, HUP, TERMP: Exit the program.
 *  * USR1: Reload the input files.
 *
 *
 * =Error Handling=
 *
 * Error handling is currently not propperly handled in IfThenElse.
 * In it current form it will exit when any error is encountered.
 *
 * =Disable script=
 * 
 * To disable a script add an empty category called 'disable'. e.g.
 *
 * {{{
 * [disable]
 * }}}
 * 
 * @see MultiAction
 * @see MultiCombine
 */
namespace IfThenElse
{
	/** Pointer to the commandline arguments. */
	private unowned string[] g_argv;
	/** Pointer to the parser */
	private Parser          parser        = null;
	/** Main loop. */
	private GLib.MainLoop   loop          = null;
	/**
	 * Config options
	 */
    private bool            quiet         = false;
    private bool            daemonize     = false;
    private bool            ignore_errors = false;
	private string?         dot_file      = null;

	const GLib.OptionEntry[] entries = {
		{"dot", 	'd',	0,	GLib.OptionArg.FILENAME, 	ref dot_file,
				"Output a flowchart off the if-the-else structure", null},
		{"background",	'b', 0, GLib.OptionArg.NONE,		out daemonize,
				"Daemonize the program", null},	
        {"ignore-errors", 'i', 0, GLib.OptionArg.NONE,      out ignore_errors,
                "Ignore unparsable input files", null},
        {"quiet", 'q', 0, GLib.OptionArg.NONE,      out quiet,
                "Reduce debug output", null},
		{null}
	};

	/**
	 * Quit the program. Dot his by terminating the mainloop
	 */
	private void quit_program()
	{
		if(loop != null) loop.quit();
	}

	/**
	 * Give all the root nodes the start signal
 	 */
	private void start()
	{
		if(parser == null) return;

		// Iterates over all input files.
		var objects = parser.get_objects();
		foreach ( GLib.Object o in objects)
		{
			if((o as Base).is_toplevel())
			{
				// Activate the toplevel one.
				if(o is BaseAction)
				{
					(o as BaseAction).Activate(o as Base);
				}
			}
		}
	}
	/**
	 * Give all the root nodes the stop signal.
	 */
	private void stop()
	{
		if(parser == null) return;

		// Iterates over all input files.
		var objects = parser.get_objects();
		foreach ( GLib.Object o in objects)
		{
			if((o as Base).is_toplevel())
			{
				// Activate the toplevel one.
				if(o is BaseAction)
				{
					(o as BaseAction).Deactivate(o as Base);
				}
			}
		}
	}
	/**
	 * Reload all the files
	 */
	private void reload_files()
	{
		GLib.message("Reload....");
		stop();
		load_argument();
		start();
	}

	/**
	 * This handles sigaction.
	 * USR1 == RELOAD
	 * HUP/TERM/INT == QUIT
	 * Other == Give message
	 */
	static void signal_handler (int signo)
	{
		if(signo == Posix.SIGUSR1) {
			reload_files();
			return;
		}

		switch (signo) {
			case Posix.SIGTERM:
			case Posix.SIGINT:
				quit_program();

				if (strsignal (signo) != null) {
					GLib.message ("Received signal:%d->'%s'", signo, strsignal (signo));
				}
				break;
			default:
				if (strsignal (signo) != null) {
					GLib.message ("Received signal:%d->'%s'", signo, strsignal (signo));
				}
				break;
		}


	}
	/**
	 * Construct the parser, load all files.
	 */
	private void load_file(string file, bool force = false)
	{
		if(force || GLib.Regex.match_simple(".*\\.(ife|ini)$", file))
		{
			GLib.message("Load file: %s", file);
			try{
				parser.add_from_file(file);
			}catch (GLib.Error e) {
                if(!ignore_errors) {
                    GLib.error("Failed to load builder file: %s, %s\n",
                            file, e.message);
                } else {
                    GLib.warning("Failed to load builder file: %s, %s\n",
                            file, e.message);
                }
			}
		}
		else
		{
			GLib.message("Ignoring: %s\n", file);
		}
	}
	/**
	 * Load content off the sub directory
	 */
	private void load_dir(string dir)
	{
		try{
			Dir d = Dir.open(dir);
			unowned string? file = null;
			while( (file = d.read_name()) != null)
			{
				var filename = GLib.Path.build_filename(dir, file);
				load(filename);
			}

		}catch(GLib.Error e) {
			GLib.error("Failed to load directory: %s, %s\n",
					dir, e.message);
		}
	}
	/**
	 * Load a path. (check if it is directory or file.
	 */
	private void load(string file, bool force = false)
	{
		if(GLib.FileUtils.test(file, GLib.FileTest.IS_REGULAR))
		{
			load_file(file, force);
		}
		else if (GLib.FileUtils.test(file, GLib.FileTest.IS_DIR))
		{
			load_dir(file);
		}
	}
	/**
	 * Load the commandline passed files
	 */
	private void load_argument()
	{
		parser = null;
		parser = new IfThenElse.Parser();

		// No file given, load default location.
		if(g_argv.length == 1)
		{
			var path = GLib.Path.build_filename(GLib.Environment.get_home_dir(), ".IfThenElse");
			load(path, false);
		}
		else
		{
			// Load the files passed on the commandline.
			for(int i =1; i < g_argv.length; i++)
			{
				unowned string file = g_argv[i];
				load(file, true);
			}
		}
	}

	// This generates a dot file for the given obect structure
	// (builder).
	static void generate_dot_file(Parser builder)
	{
		FileStream fp = FileStream.open(dot_file, "w");
		// Print header.
		fp.printf("digraph FlowChart {\n");
		fp.printf("""
				node [
					fontname = "Bitstream Vera Sans"
			         fontsize = 8
			         shape = "record"
			     ]
		 """);
		// Iterates over all input files.
		// Find the root item(s) and make them generate the rest
		// off the dot file.
		var objects = builder.get_objects();
		foreach ( GLib.Object o in objects)
		{
			if((o as Base).is_toplevel())
			{
				if(o is BaseAction)
				{
					(o as BaseAction).output_dot(fp);
				}
			}
		}
		fp.printf("}\n");
		fp = null;
	}

	/**
	 * Background ifthenelse.
	 */
	static void background()
	{
		// Duplicate and exit the parent.
		var pid = Posix.fork();
		if(pid < 0){
			GLib.error("Failed to fork to the background");
		}
		if(pid > 0) {
			// Main thread.
			Posix.exit(0);
		}
	}
	/**
 	 * Log handler.
	 */
	static void my_log_handler(string? domain, GLib.LogLevelFlags level, string message)
	{
		if(!quiet)
		{
			GLib.Log.default_handler(domain,level, message);
		}
	}

	static int main(string[] argv)
	{

		// Register the types.
		// Checks
		var a  = typeof(ExternalToolCheck);
		a = typeof(TimeCheck);
		a = typeof(OutputWatch);

		// Actions.
		a = typeof(ExternalToolAction);
		a = typeof(MultiAction);

		// Triggers
		a = typeof(ExternalToolTrigger);
		a = typeof(TimerTrigger);
		a = typeof(InitTrigger);
		a = typeof(ClockTrigger);

		// other
		a = typeof(MultiCombine);
		a = typeof(AndCombine);

		// Commandline options parsing.
		GLib.OptionContext og = new GLib.OptionContext("IfThenElse");
		og.add_main_entries(entries,null);
		try{
			og.parse(ref argv);
		}catch (Error e) {
			GLib.error("Failed to parse command line options: %s\n",
					e.message);
		}
		g_argv = argv;

		// Log handler
		GLib.Log.set_handler(null,
				GLib.LogLevelFlags.LEVEL_INFO|GLib.LogLevelFlags.LEVEL_DEBUG|
				GLib.LogLevelFlags.LEVEL_MESSAGE,
				my_log_handler);

		// Load the setup file.
		load_argument();

		// Generate a dot file.
		if(dot_file != null)
		{
			generate_dot_file(parser);
			parser = null;
			// Exit succesfull
			return 0;
		}


		if(daemonize) {
			background();
		}
		// Create main loop.
		loop = new GLib.MainLoop();

		/**
		 * Handle signals
		 */
		var empty_mask = Posix.sigset_t ();
		Posix.sigemptyset (empty_mask);

		var act = Posix.sigaction_t ();
		act.sa_handler = signal_handler;
		act.sa_mask = empty_mask;
		act.sa_flags = 0;

		Posix.sigaction (Posix.SIGTERM, act, null);
		Posix.sigaction (Posix.SIGINT, act, null);
		Posix.sigaction (Posix.SIGHUP, act, null);
		Posix.sigaction (Posix.SIGUSR1, act, null);


		// Run program.
		start();
		loop.run();

		GLib.message("Quit....");

		stop();
		GLib.message("Cleanup....");
		// Destroy
		parser = null;
		return 0;
	}
}
