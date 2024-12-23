# redmics - redmine ics export plugin
# Copyright (c) 2010-2011  Frank Schwarz, frank.schwarz@buschmais.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require 'redmine'

require_relative './lib/sidebar_hooks'
require_relative './lib/userprefs_hooks'
require_relative './lib/application_controller_patches'
require_relative './lib/settings_controller_patches'
require_relative './lib/model_patches'
require_relative './lib/my_controller_patches'

Redmine::Plugin.register :redmine_ics_export do
  name 'redmine ics export plugin (aka redmics)'
  author 'Frank Schwarz'
  description 'ICalendar view of issue- and version-deadlines'
  version '6.0.0.dev'
  url 'https://github.com/buschmais/redmics'
  author_url 'http://www.buschmais.de/author/frank/'
  settings(
    :default => {
      :redmics_icsrender_issues => :vevent_end_date,
      :redmics_icsrender_versions => :vevent_end_date,
      :redmics_icsrender_summary => :status,
      :redmics_icsrender_description => :full,
    },
    :partial => 'settings/redmics_settings')
end
