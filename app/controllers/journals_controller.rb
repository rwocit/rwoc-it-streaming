# Redmine - project management software
# Copyright (C) 2006-2012  Jean-Philippe Lang
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

class JournalsController < ApplicationController
  before_filter :find_journal, :only => [:edit, :diff]
  before_filter :find_issue, :only => [:new]
  before_filter :find_optional_project, :only => [:index]
  before_filter :authorize, :only => [:new, :edit, :diff]
  accept_rss_auth :index
  menu_item :issues

  helper :issues
  helper :custom_fields
  helper :queries
  include QueriesHelper
  helper :sort
  include SortHelper

  def index
    retrieve_query
    sort_init 'id', 'desc'
    sort_update(@query.sortable_columns)

    if @query.valid?
      @journals = @query.journals(:order => "#{Journal.table_name}.created_on DESC",
                                  :limit => 25)
    end
    @title = (@project ? @project.name : Setting.app_title) + ": " + (@query.new_record? ? l(:label_changes_details) : @query.name)
    render :layout => false, :content_type => 'application/atom+xml'
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def diff
    @issue = @journal.issue
    if params[:detail_id].present?
      @detail = @journal.details.find_by_id(params[:detail_id])
    else
      @detail = @journal.details.detect {|d| d.prop_key == 'description'}
    end
    (render_404; return false) unless @issue && @detail
    @diff = Redmine::Helpers::Diff.new(@detail.value, @detail.old_value)
  end

  def new
    journal = Journal.find(params[:journal_id]) if params[:journal_id]
    if journal
      user = journal.user
      text = journal.notes
    else
      user = @issue.author
      text = @issue.description
    end
    # Replaces pre blocks with [...]
    text = text.to_s.strip.gsub(%r{<pre>((.|\s)*?)</pre>}m, '[...]')
    @content = "#{ll(Setting.default_language, :text_user_wrote, user)}\n> "
    @content << text.gsub(/(\r?\n|\r\n?)/, "\n> ") + "\n\n"
  end

  def edit
    (render_403; return false) unless @journal.editable_by?(User.current)
    if request.post?
      @journal.update_attributes(:notes => params[:notes]) if params[:notes]
      @journal.destroy if @journal.details.empty? && @journal.notes.blank?
      call_hook(:controller_journals_edit_post, { :journal => @journal, :params => params})
      respond_to do |format|
        format.html { redirect_to :controller => 'issues', :action => 'show', :id => @journal.journalized_id }
        format.js { render :action => 'update' }
      end
    else
      respond_to do |format|
        format.html {
          # TODO: implement non-JS journal update
          render :nothing => true
        }
        format.js
      end
    end
  end

  private

  def find_journal
    @journal = Journal.find(params[:id])
    @project = @journal.journalized.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  # TODO: duplicated in IssuesController
  def find_issue
    @issue = Issue.find(params[:id], :include => [:project, :tracker, :status, :author, :priority, :category])
    @project = @issue.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
