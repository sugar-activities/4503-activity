#!/usr/bin/env python
# -*- coding: utf-8 -*-

#   OperaActivity.py por:
#   Flavio Danesse <fdanesse@gmail.com>
#   CeibalJAM! - Uruguay
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

import sys, os, gtk, pygtk, subprocess

from sugar.activity import activity

ejecutable= os.path.join(os.getcwd(), "opera.sh")
widman= os.path.join(os.getcwd(),"opera-widget-manager")
opera= os.path.join(os.getcwd(), "lib", "opera")

os.chmod(ejecutable, 0755)
os.chmod(widman, 0755)
os.chmod(opera, 0755)

def operarun():
	subprocess.Popen("bash %s" % (ejecutable), shell=True)

class OperaActivity(activity.Activity):
	def __init__(self, handle):
		activity.Activity.__init__(self, handle, False)
		self.set_canvas(gtk.VBox())
		self.show_all()

		operarun()
