class SearchHelper

  private

  require_here 'cache_helper'

  def initialize(start_page, end_page)
    @cache = CacheHelper.new
    @start_page_id = @cache.get_id(start_page)
    @end_page_id = @cache.get_id(end_page)
    #@max_duration = max_duration
    @chain = Array.new
    @last_reported = @start_time = Time.now
    @done = false
    @depth = 0
  end

  def check_pages(pages, depth)
    if depth == 0
      pages.each do |page|
        if check_page(page)
          return true
        end
      end
    else
      pages.each do |page|
        if check_pages(@cache.get_link_ids(page), depth - 1)
          @chain.push(page)
          return true
        end
      end
    end
    false
  end

  def check_page(page)
    @cache.get_link_ids(page).each do |link|
      if run_backlink(link)
        @chain.push(page)
        @done = true
        return true
      end
    end
    false
  end

  def run_backlink(target_page)
    pages = [@end_page_id]
    check_pages_backlinks(pages, @depth, target_page)
  end

  def check_pages_backlinks(pages, depth, target_page)
    if depth == 0
      pages.each do |page|
        if check_page_backlinks(page, target_page)
          return true
        end
      end
    else
      pages.each do |page|
        if check_pages_backlinks(@cache.get_backlink_ids(page), depth - 1, target_page)
          @chain.unshift(page)
          return true
        end
      end
    end
    false
  end

  def check_page_backlinks(page, target_page)
    @cache.get_backlink_ids(page).each do |link|
      if link == target_page
        @chain.unshift(target_page)
        @chain.unshift(page)
        return true
      end
    end
    false
  end

  #def reset_duration(max_duration)
  #  @last_dot = @last_reported = @start_time = Time.now
  #  @max_duration = max_duration
  #end

  public

  def run
    while true
      pages = [@start_page_id]
      if check_pages(pages, @depth)
        break
      end
      @depth += 1
    end

    @chain.reverse!
    @cache.get_titles(@chain)
  end

  def done?
    @done
  end

end