/*
 * Copyright 2011-2015  Martijn Koedam <qball@gmpclient.org>
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

using GLib ;
using Posix ;

namespace IfThenElse{
    /**
     * Execute an external tool.
     *
     * This executes an external tool.
     *
     * =Example=
     *
     * {{{
     * [EAction]
     * type=ExternalToolAction
     * cmd=mpc play
     * }}}
     */
    public class ExternalToolAction : BaseAction, Base {
        public string cmd { get ; set ; default = "" ; }
        /**
         * If the property kill_child is set to true, it kills the
         * client when the object is de_is_active.
         */
        public bool kill_child { get ; set ; default = false ; }

        private GLib.Pid pid = 0 ;
        private void child_watch_called(GLib.Pid p, int status) {
            GLib.Process.close_pid (p) ;
            GLib.message ("Child watch called.\n") ;
            pid = 0 ;
        }

        private void start_application() {
            GLib.message ("%s: %s", this.name, "start application") ;
            if( kill_child ){
                stop_application () ;
                pid = 0 ;
            }
            if( pid == 0 ){
                string[3] argv = new string[3] ;
                GLib.message ("Start application\n") ;
                try {
                    argv[0] = "bash" ;
                    argv[1] = "-c" ;
                    argv[2] = cmd ;
                    foreach( var s in argv ){
                        GLib.message ("argv: %s\n", s) ;
                    }
                    GLib.Process.spawn_async (null, argv, null,
                                              SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD, null, out pid) ;

                    GLib.ChildWatch.add (pid, child_watch_called) ;
                } catch (Error e)
                {
                    GLib.warning ("Failed to start application: %s", e.message) ;
                }
            }
        }

        private void stop_application() {
            if( pid > 0 ){
                GLib.message ("%s: Killing pid: %i\n", this.name, (int) pid) ;
                Posix.kill ((pid_t) pid, 1) ;
            }
        }

        public void Activate(Base p) {
            _is_active = true ;
            start_application () ;
        }

        public void Deactivate(Base p) {
            GLib.message ("%s: Deactivate\n", this.name) ;
            _is_active = false ;
            stop_application () ;
        }

        /**
         * Generate dot output for this node
         */
        public override string get_dot_description() {
            return "%s\\n(%s)".printf (this.get_public_name (), cmd) ;
        }

    }
}

