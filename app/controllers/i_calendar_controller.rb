# redmics - redmine ics export plugin
# Copyright (c) 2010-2021 Frank Schwarz, frank.schwarz@buschmais.com
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

require 'icalendar'
require_relative '../../lib/redmics/export'
require_relative '../../lib/redmics/query_conditions'

class ICalendarController < ApplicationController
  unloadable
  
  accept_rss_auth :index

  before_action :find_user,
                :find_optional_project,
                :find_optional_query,
                :decode_rendering_settings_from_url,
                :authorize_access, 
                :check_and_complete_params,
                :load_settings
  
  def index
    e = Redmics::Export.new(self)
    e.settings(:user => @user,
               :project => @project,
               :query => @query,
               :alarm => params[:alarm],
               :status => params[:status] ? params[:status].to_sym : nil,
               :assignment => params[:assignment] ? params[:assignment].to_sym : nil,
               :issue_strategy => @settings[:redmics_icsrender_issues].to_sym,
               :version_strategy => @settings[:redmics_icsrender_versions].to_sym,
               :summary_strategy => @settings[:redmics_icsrender_summary].to_sym,
               :description_strategy => @settings[:redmics_icsrender_description].to_sym
               )
    send_data(e.icalendar.to_ical, :type => 'text/calendar; charset=utf-8')
  end

private

  def find_user
    @user = User.current
  rescue ActiveRecord::RecordNotFound
    render_403
  end

  def find_optional_project
    return true unless params[:project_id]
    @project = Project.find_by_identifier(params[:project_id]);
    return false unless @project
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
  def find_optional_query
    return true unless params[:query_id]
    @query = IssueQuery.find_by_id(params[:query_id])
    return false unless @query
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def decode_rendering_settings_from_url
    options = [:none, :vevent_full_span, :vevent_end_date, :vevent_start_and_end_date, :vtodo, :mega_calendar]
    options_summary = [:plain, :status, :ticket_number_and_status]
    options_description = [:plain, :url_and_version, :full_no_url, :full]
    @rendering = {}
    if params[:render_issues] =~ /[0-5]/
      @rendering[:redmics_icsrender_issues] = options[params[:render_issues].to_i]
    end
    if params[:render_versions] =~ /[0-3]/
      @rendering[:redmics_icsrender_versions] = options[params[:render_versions].to_i]
    end
    if params[:render_summary] =~ /[0-2]/
      @rendering[:redmics_icsrender_summary] = options_summary[params[:render_summary].to_i]
    end
    if params[:render_description] =~ /[0-3]/
      @rendering[:redmics_icsrender_description] = options_description[params[:render_description].to_i]
    end
  end
  
  def authorize_access
    # we have a key but no autenticated user
    (render_404; return false) if params[:key] && @user.anonymous?
    # we have a project-id but no project
    (render_404; return false) if params[:project_id] && @project.nil?
    # we have a query-id but no query
    (render_404; return false) if params[:query_id] && @query.nil?
    # we answer with 'not found' if parameters seem to be bogus
    (render_404; return false) unless (params[:assignment] || params[:query_id])
    # we have a project but calendar viewing is forbidden for the (possibly anonymous) user
    (render_403; return false) if @project && ! @user.allowed_to?(:view_calendar, @project)
    # we do not have a project and calendar viewing is globally forbidden for the autenticated user
    (render_403; return false) if @project.nil? && ! @user.allowed_to?(:view_calendar, nil, :global => true)
  end
  
  def check_and_complete_params
    # status = all is the default
    params[:status] ||= :all
  end
  
  def load_settings
    defaults = Redmine::Plugin.find(:redmine_ics_export).settings[:default]
    global_prefs = Setting.plugin_redmine_ics_export
    @settings = { }
    defaults.keys.each { |item|
      @settings[item] = @rendering[item] ||
        @user.pref[item] ||
        global_prefs[item] ||
        defaults[item]
    }
  end
end
