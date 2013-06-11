class CacheHelper

  private

  require_here 'db_helper'

  def initialize
    @links = Hash.new(nil)
    @backlinks = Hash.new(nil)
    @db = DbHelper.new('cache.db')
    @show_activity_counter = 0
    #puts
    #show_status
    #puts
  end

  def show_activity
    @show_activity_counter += 1
    if @show_activity_counter >= 100000
      print '!'
      @show_activity_counter = 0
    end
  end

  def length
    @links.length + @backlinks.length
  end

  def show_status
    @db.show_status
  end

  public

  def get_id(title)
    @db.get_id(title)
  end

  def get_link_ids(id)
    link_ids = @links[id]
    unless link_ids.nil?
      show_activity
      return link_ids
    end
    link_ids = @db.get_link_ids(id)
    @links.store(id, link_ids)
    link_ids
  end

  def get_backlink_ids(id)
    backlink_ids = @backlinks[id]
    unless backlink_ids.nil?
      show_activity
      return backlink_ids
    end
    backlink_ids = @db.get_backlink_ids(id)
    @backlinks.store(id, backlink_ids)
    backlink_ids
  end

  def get_titles(ids)
    @db.get_titles(ids)
  end
end