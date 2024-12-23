# redmics - redmine ics export plugin
# Copyright (c) 2011-2024  Frank Schwarz, frank.schwarz@buschmais.com
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

require_dependency 'user_preference'

module ModelPatches
  module UserPreferencePatch
    def self.included(base)
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)
    end

    module ClassMethods
    end

    module InstanceMethods
      def unset(*args)
        h = read_attribute(:others).dup || {}
        args.flatten.each() { |key|
          h.delete(key)
        }
        write_attribute(:others, h)
      end
    end    
  end
end

UserPreference.send(:include, ModelPatches::UserPreferencePatch)
