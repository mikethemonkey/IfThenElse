/**
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

namespace IfThenElse
{
	public class InitTrigger : BaseTrigger
	{
		private bool init = true;	
		public bool always_trigger {get;set;default = false;}
		
		public override void enable_trigger()
		{
			if(init || always_trigger) {
				this.fire();
			}
			init = false;
		}

		public override void disable_trigger()
		{
		}
		
		public override void output_dot(FileStream fp)
		{
			fp.printf("\"%s\" [label=\"%s\\nInit trigger\", shape=oval]\n", 
						this.name,
						this.name);
			fp.printf("\"%s\" -> \"%s\"\n", this.name, action.name);
			this.action.output_dot(fp);
		}
	}
}