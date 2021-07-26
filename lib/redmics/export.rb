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

module Redmics
  class Export
    include Redmics
    include Redmine::I18n

    def initialize(controller)
      @controller = controller
      @priority_count = IssuePriority.all.length
    end

    def settings(args)
      @user = args[:user]
      @project = args[:project]
      @query = args[:query]
      @status = args[:status]
      @alarm = args[:alarm]
      @assignment = args[:assignment]
      @issue_strategy = args[:issue_strategy]
      @version_strategy = args[:version_strategy]
      @summary_strategy = args[:summary_strategy]
      @description_strategy = args[:description_strategy]
    end

    def icalendar
      issues_renderer = create_issues_renderer @issue_strategy
      versions_renderer = create_versions_renderer @version_strategy

      if @query
        (issues, versions) = redmine_query
      else
        (issues, versions) = redmics_query
      end

      events = []
      events += issues.collect(&issues_renderer).flatten
      events += versions.collect(&versions_renderer).flatten

      cal = Icalendar::Calendar.new
      cal.publish
      events.each { |event| cal.add_event(event) }
      return cal
    end

  private

    def redmine_query
      begin
        issues = []
        versions = []
        if @query.valid?
          # query: issues
          issues = @query.issues(
            :include => [:tracker, :assigned_to, :priority, :fixed_version, :author],
          ) unless @issue_strategy == :none
          # query: versions -> skip
        end
      rescue Exception => e
        # we will just deliver an empty ical file instead of showing an error page
        @controller.logger.warn('No issues have been selected. ' + e.to_s)
      end
      return [issues, versions]
    end

    def redmics_query
      begin
        case @status
        when :open
          issue_status_condition = ["#{IssueStatus.table_name}.is_closed = ?", false]
          version_status_condition = ["#{Version.table_name}.status <> ?", 'closed']
        when :all
          issue_status_condition = []
          version_status_condition = []
        else
          raise "Unknown status: '#{@status}'."
        end

        case @assignment
        when :my
          raise 'Anonymous user cannot have issues assigned.' if @user.anonymous?
          assigned_to_condition = ["assigned_to_id = #{@user.id}"]
        when :assigned
          assigned_to_condition = ["assigned_to_id is not null"]
        when :all
          assigned_to_condition = []
        else
          raise "Unknown assignment: '#{@assignment}.'"
        end

        @query = IssueQuery.new(:name => "_")
        @query.project = @project
        @query.filters = nil
        issues = []
        versions = []

        # query: issues
        c = QueryConditions.new()
        c << issue_status_condition unless issue_status_condition.empty?
        c << assigned_to_condition unless assigned_to_condition.empty?
        issues = @query.issues(
          :include => [:tracker, :assigned_to, :priority, :fixed_version, :author],
          :conditions => c.conditions) unless @issue_strategy == :none
        # query: versions
        c = QueryConditions.new()
        c << version_status_condition unless version_status_condition.empty?
        versions =  @query.versions(
          :conditions => c.conditions
        ) unless @version_strategy == :none
        c << ["#{Version.table_name}.sharing = ?", 'system']
        versions << @query.versions(
          :conditions => c.conditions
        ) unless @version_strategy == :none
        versions.flatten!
      rescue Exception => e
        # we will just deliver an empty ical file instead of showing an error page
        @controller.logger.warn('No issues have been selected. ' + e.to_s)
        issues = []
        versions = []
      end
      return [issues, versions]
    end

    def create_issues_renderer(type)
      case type
      when :none
        lambda { |issue|
          []
        }
      when :vevent_full_span
        lambda { |issue|
          result = create_issue_vevent_full_span(issue)
          apply_issue_common_properties(issue, result)
          apply_issue_event_properties(issue, result)
          apply_issue_alarm(issue, result) unless @alarm.nil?
          enhance_issue_summary(issue, result)
          enhance_issue_description(issue, result)
          result
        }
      when :vevent_end_date
        lambda { |issue|
          result = create_issue_vevent_end_date(issue)
          apply_issue_common_properties(issue, result)
          apply_issue_event_properties(issue, result)
          apply_issue_alarm(issue, result) unless @alarm.nil?
          enhance_issue_summary(issue, result)
          enhance_issue_description(issue, result)
          result
        }
      when :vevent_start_and_end_date
        lambda { |issue|
          result = create_issue_vevent_start_and_end_date(issue)
          apply_issue_common_properties(issue, result)
          apply_issue_event_properties(issue, result)
          apply_issue_alarm(issue, result) unless @alarm.nil?
          enhance_issue_summary(issue, result)
          enhance_issue_description(issue, result)
          result
        }
      when :vtodo
        lambda { |issue|
          result = create_issue_vtodo(issue)
          apply_issue_common_properties(issue, result)
          apply_issue_todo_properties(issue, result)
          apply_issue_alarm(issue, result) unless @alarm.nil?
          enhance_issue_summary(issue, result)
          enhance_issue_description(issue, result)
          result
        }
      end
    end

    def create_versions_renderer(type)
      case type
      when :none
        lambda { |version|
          []
        }
      when :vevent_full_span
        lambda { |version|
          result = create_version_vevent_full_span(version)
          apply_version_common_properties(version, result)
          apply_version_event_properties(version, result)
          enhance_version_description(version, result)
          result
        }
      when :vevent_end_date
        lambda { |version|
          result = create_version_vevent_end_date(version)
          apply_version_common_properties(version, result)
          apply_version_event_properties(version, result)
          enhance_version_description(version, result)
          result
        }
      when :vevent_start_and_end_date
        lambda { |version|
          result = create_version_vevent_start_and_end_date(version)
          apply_version_common_properties(version, result)
          apply_version_event_properties(version, result)
          enhance_version_description(version, result)
          result
        }
      when :vtodo
        lambda { |version|
          result = create_version_vtodo(version)
          apply_version_common_properties(version, result)
          apply_version_todo_properties(version, result)
          enhance_version_description(version, result)
          result
        }
      end
    end


    def create_issue_vevent_full_span(issue)
      start_date, due_date = issue_period(issue)
      return [] if start_date.nil? || due_date.nil?
      event = Icalendar::Event.new
      event.dtstart = Icalendar::Values::Date.new(start_date)
      event.dtend = Icalendar::Values::Date.new(due_date + 1)
      event.uid = "id:redmics:project:#{issue.project_id}:issue:#{issue.id}@#{Setting.host_name}"
      return [event]
    end

    def create_issue_vevent_end_date(issue)
      due_date = issue_period(issue)[1]
      return [] if due_date.nil?
      event = Icalendar::Event.new
      event.dtstart = Icalendar::Values::Date.new(due_date)
      event.dtend = Icalendar::Values::Date.new(due_date + 1)
      event.uid = "id:redmics:project:#{issue.project_id}:issue:#{issue.id}@#{Setting.host_name}"
      return [event]
    end

    def create_issue_vevent_start_and_end_date(issue)
      start_date, due_date = issue_period(issue)
      if start_date.nil? && due_date.nil?
        return []
      elsif start_date == due_date
        event = Icalendar::Event.new
        event.dtstart = Icalendar::Values::Date.new(start_date)
        event.dtend = Icalendar::Values::Date.new(start_date + 1)
        event.summary = "<> #{issue.subject}"
        event.uid = "id:redmics:project:#{issue.project_id}:issue:#{issue.id}@#{Setting.host_name}"
        return [event]
      end
      result = []
      unless start_date.nil?
        event = Icalendar::Event.new
        event.dtstart = Icalendar::Values::Date.new(start_date)
        event.dtend = Icalendar::Values::Date.new(start_date + 1)
        event.summary = "> #{issue.subject}"
        event.uid = "id:redmics:project:#{issue.project_id}:issue:#{issue.id}:s@#{Setting.host_name}"
        result << event
      end
      unless due_date.nil?
        event = Icalendar::Event.new
        event.dtstart = Icalendar::Values::Date.new(due_date)
        event.dtend = Icalendar::Values::Date.new(due_date + 1)
        event.summary = "< #{issue.subject}"
        event.uid = "id:redmics:project:#{issue.project_id}:issue:#{issue.id}:e@#{Setting.host_name}"
        result << event
      end
      return result
    end

    def create_issue_vtodo(issue)
      start_date, due_date = issue_period(issue)
      todo = Icalendar::Todo.new
      unless start_date.nil?
        todo.dtstart = Icalendar::Values::Date.new(start_date)
      end
      unless due_date.nil?
        todo.due = Icalendar::Values::Date.new(due_date)
      end
      todo.uid = "id:redmics:project:#{issue.project_id}:issue:#{issue.id}@#{Setting.host_name}"
      return [todo]
    end

    def apply_issue_common_properties(issue, result)
      result.each { |event|
        event.summary = "#{issue.subject}" unless event.summary
        event.priority = map_priority issue.priority.position
        event.created = Icalendar::Values::Date.new(issue.created_on)
        event.last_modified = issue.updated_on.to_datetime unless issue.updated_on.nil?
        event.description = issue.description unless issue.description.nil?
        event.categories = [@controller.l(:label_issue).upcase]
        event.contact = Icalendar::Values::Text.new(issue.assigned_to.name, 
          {"ALTREP" => "mailto:#{issue.assigned_to.mail}"}) unless issue.assigned_to.nil?
        event.organizer = Icalendar::Values::CalAddress.new("mailto:#{issue.author.mail}", cn: issue.author.name)
        event.url = @controller.url_for(:controller => 'issues', :action => 'show', :id => issue.id)
        event.sequence = issue.lock_version
      }
    end

    def apply_issue_alarm(issue, result)
      if !result.empty?
        alarm_trigger = @alarm # strange but seems to be required
        result.last.alarm { |alarm|
          alarm.description = "This is an event reminder"
          alarm.trigger = alarm_trigger
        }
      end
    end

    def apply_issue_event_properties(issue, result)
      result.each { |event|
        event.status = issue.assigned_to ? "CONFIRMED" : "TENTATIVE" unless issue.closed?
      }
    end

    def apply_issue_todo_properties(issue, result)
      result.each { |todo|
        if issue.closed?
          todo.status = "COMPLETED"
          todo.completed = issue.updated_on.to_datetime
          todo.percent_complete = 100
        elsif issue.assigned_to
          todo.status = "IN-PROCESS"
          todo.percent_complete = issue.done_ratio ? issue.done_ratio.to_i : 0
        else
          todo.status = "NEEDS-ACTION"
        end
      }
    end

    def create_version_vevent_full_span(version)
      start_date, due_date = version_period(version)
      return [] if start_date.nil? || due_date.nil?
      event = Icalendar::Event.new
      event.dtstart = Icalendar::Values::Date.new(start_date)
      event.dtend = Icalendar::Values::Date.new(due_date + 1)
      event.uid = "id:redmics:project:#{version.project_id}:version:#{version.id}@#{Setting.host_name}"
      return [event]
    end

    def create_version_vevent_end_date(version)
      due_date = version_period(version)[1]
      return [] if due_date.nil?
      event = Icalendar::Event.new
      event.dtstart = Icalendar::Values::Date.new(due_date)
      event.dtend = Icalendar::Values::Date.new(due_date + 1)
      event.uid = "id:redmics:project:#{version.project_id}:version:#{version.id}@#{Setting.host_name}"
      return [event]
    end

    def create_version_vevent_start_and_end_date(version)
      start_date, due_date = version_period(version)
      if start_date.nil? && due_date.nil?
        return []
      elsif start_date == due_date
        event = Icalendar::Event.new
        event.dtstart = Icalendar::Values::Date.new(start_date)
        event.dtend = Icalendar::Values::Date.new(start_date + 1)
        event.summary = "<#> #{l(:label_version)} #{version.name}"
        event.uid = "id:redmics:project:#{version.project_id}:version:#{version.id}@#{Setting.host_name}"
        return [event]
      end
      result = []
      unless start_date.nil?
        event = Icalendar::Event.new
        event.dtstart = Icalendar::Values::Date.new(start_date)
        event.dtend = Icalendar::Values::Date.new(start_date + 1)
        event.summary = ">> #{l(:label_version)} #{version.name}"
        event.uid = "id:redmics:project:#{version.project_id}:version:#{version.id}:s@#{Setting.host_name}"
        result << event
      end
      unless due_date.nil?
        event = Icalendar::Event.new
        event.dtstart = Icalendar::Values::Date.new(due_date)
        event.dtend = Icalendar::Values::Date.new(due_date + 1)
        event.summary = "<< #{l(:label_version)} #{version.name}"
        event.uid = "id:redmics:project:#{version.project_id}:version:#{version.id}:e@#{Setting.host_name}"
        result << event
      end
      return result
    end

    def create_version_vtodo(version)
      start_date, due_date = version_period(version)
      todo = Icalendar::Todo.new
      unless start_date.nil?
        todo.dtstart = Icalendar::Values::Date.new(start_date)
      end
      unless due_date.nil?
        todo.due = Icalendar::Values::Date.new(due_date)
      end
      todo.uid = "id:redmics:project:#{version.project_id}:version:#{version.id}@#{Setting.host_name}"
      return [todo]
    end

    def apply_version_common_properties(version, result)
      result.each { |event|
        event.summary = "#{@controller.l(:label_version)} #{version.name}" unless event.summary
        event.created = Icalendar::Values::Date.new(version.created_on)
        event.last_modified = version.updated_on.to_datetime unless version.updated_on.nil?
        event.description = version.description unless version.description.nil?
        event.categories = [@controller.l(:label_version).upcase]
        event.url = @controller.url_for(:controller => 'versions', :action => 'show', :id => version.id)
        days = (version.updated_on.to_i - version.created_on.to_i) / 86400
        event.sequence = days
      }
    end

    def apply_version_event_properties(version, result)
      result.each { |event|
        event.status = "CONFIRMED" unless version.closed?
      }
    end

    def apply_version_todo_properties(version, result)
      result.each { |todo|
        if version.closed?
          todo.status = "COMPLETED"
          todo.completed = version.updated_on.to_datetime
          todo.percent_complete = 100
        else
          todo.status = "IN-PROCESS"
          todo.percent_complete = version.completed_percent.to_i
        end
      }
    end

    def enhance_issue_summary(issue, result)
      result.each { |item|
        case @summary_strategy
        when :plain
          # no action
        when :status
          item.summary = "#{item.summary} (#{issue.status.name})" if issue.status
        when :ticket_number_and_status
          item.summary = "#{item.summary} (#{issue.status.name})" if issue.status
          if /(<|>|<>) (.*)/ =~ item.summary
            m = Regexp.last_match
            item.summary = "#{m[1]} #{issue.tracker} ##{issue.id}: #{m[2]}"
          else
            item.summary = "#{issue.tracker} ##{issue.id}: #{item.summary}"
          end
        else
          raise "Unknown summary_strategy: '#{@summary_strategy}'."
        end
      }
    end

    def enhance_issue_description(issue, result)
      result.each { |item|
        case @description_strategy
        when :plain
          # no action
        when :url_and_version
          header = []
          header << "#{issue.tracker} ##{issue.id}: #{item.url}"
          header << "#{@controller.l(:field_project)}: #{issue.project.name}" if issue.project
          header << "#{@controller.l(:field_fixed_version)}: #{issue.fixed_version}" if issue.fixed_version
          if item.description
            item.description = header.join("\n") + "\n\n" + item.description
          else
            item.description = header.join("\n")
          end
        when :full_no_url
          header = []
          header << "#{issue.tracker} ##{issue.id}"
          header << "#{@controller.l(:field_project)}: #{issue.project.name}" if issue.project
          header << "#{@controller.l(:field_author)}: #{issue.author.name}" if issue.author
          header << "#{@controller.l(:field_status)}: #{issue.status.name}" if issue.status
          header << "#{@controller.l(:field_priority)}: #{issue.priority}" if issue.priority
          header << "#{@controller.l(:field_assigned_to)}: #{issue.assigned_to.name}" if issue.assigned_to
          header << "#{@controller.l(:field_category)}: #{issue.category.name}" if issue.category
          header << "#{@controller.l(:field_fixed_version)}: #{issue.fixed_version}" if issue.fixed_version
          if item.description
            item.description = header.join("\n") + "\n\n" + item.description
          else
            item.description = header.join("\n")
          end
        when :full
          header = []
          header << "#{issue.tracker} ##{issue.id}: #{item.url}"
          header << "#{@controller.l(:field_project)}: #{issue.project.name}" if issue.project
          header << "#{@controller.l(:field_author)}: #{issue.author.name}" if issue.author
          header << "#{@controller.l(:field_status)}: #{issue.status.name}" if issue.status
          header << "#{@controller.l(:field_priority)}: #{issue.priority}" if issue.priority
          header << "#{@controller.l(:field_assigned_to)}: #{issue.assigned_to.name}" if issue.assigned_to
          header << "#{@controller.l(:field_category)}: #{issue.category.name}" if issue.category
          header << "#{@controller.l(:field_fixed_version)}: #{issue.fixed_version}" if issue.fixed_version
          if item.description
            item.description = header.join("\n") + "\n\n" + item.description
          else
            item.description = header.join("\n")
          end
        else
          raise "Unknown description_strategy: '#{@description_strategy}'."
        end
      }
    end

    def enhance_version_description(version, result)
      result.each { |item|
        case @description_strategy
        when :plain
          # no action
        when :url_and_version
          header = []
          header << "#{@controller.l(:field_url)}: #{item.url}"
          if item.description
            item.description = header.join("\n") + "\n\n" + item.description
          else
            item.description = header.join("\n")
          end
        when :full_no_url
          header = []
          header << "#{@controller.l(:field_url)}"
          header << "#{@controller.l(:field_project)}: #{version.project.name}" if version.project
          header << "#{@controller.l(:field_status)}: #{version.status}" if version.status
          if item.description
            item.description = header.join("\n") + "\n\n" + item.description
          else
            item.description = header.join("\n")
          end
        when :full
          header = []
          header << "#{@controller.l(:field_url)}: #{item.url}"
          header << "#{@controller.l(:field_project)}: #{version.project.name}" if version.project
          header << "#{@controller.l(:field_status)}: #{version.status}" if version.status
          if item.description
            item.description = header.join("\n") + "\n\n" + item.description
          else
            item.description = header.join("\n")
          end
        else
          raise "Unknown description_strategy: '#{@description_strategy}'."
        end
      }
    end

    def issue_period(issue)
      start_date = issue.start_date || (issue.fixed_version.start_date unless issue.fixed_version.nil?)
      due_date = issue.due_date || (issue.fixed_version.due_date unless issue.fixed_version.nil?)
      return [start_date, due_date]
    end

    def version_period(version)
      return [version.start_date, version.due_date]
    end

    # isses_priority goes from 'low' (1), 'normal' (2) to 'immediate' (@priority_count)
    # icalendar priority goes from 'urgent' (1) to 'low' (9) (btw. 0 = undefined)
    def map_priority(isses_priority)
      case isses_priority
      when 1; 9
      when 2; 5
      when 3..@priority_count; 1
      else 9
      end
    end
  end
end
