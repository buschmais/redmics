# redmics - redmine ics export plugin
# Copyright (c) 2011  Frank Schwarz, frank.schwarz@buschmais.com
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

module MyControllerPatches
  def self.included(base)
    base.class_eval {
      include InstanceMethods
    }
  end

  module InstanceMethods
    def redmics_settings
      @user = User.current
      defaults = Redmine::Plugin.find(:redmine_ics_export).settings[:default]
      global_prefs = Setting.plugin_redmine_ics_export
      if request.post?
        defaults.keys.each { |item|
          @user.pref[item] = params[:settings][item]
        }
        if @user.save
          @user.pref.save
          flash.now[:notice] = l(:notice_redmics_userprefs_updated)
        end
      end
      @settings = { }
      defaults.keys.each { |item|
        @settings[item] = @user.pref[item] || global_prefs[item] || defaults[item]
      }
    end

    def redmics_settings_reset
      @user = User.current
      if @user.save
        defaults = Redmine::Plugin.find(:redmine_ics_export).settings[:default]
        @user.pref.unset(defaults.keys)
        @user.pref.save
        flash[:notice] = l(:notice_redmics_userprefs_reset)
      end
      redirect_to :action => 'redmics_settings'
    end
  end
end

MyController.send(:include, MyControllerPatches)
