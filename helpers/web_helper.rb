require 'open-uri'
require 'json'

class WebHelper

  private

  require_here 'uri_helper'

  def run_backlinks(uri)
    json = open(uri.build_backlinks).read
    result = JSON.parse(json)
    #backlinks = result['query']['backlinks']
    blcontinue_s = blcontinue(result)
    unless blcontinue_s.nil?
      print '...'
      uri.continue = blcontinue_s
      next_result = run_backlinks(uri)
      next_backlinks = next_result['query']['backlinks']
      result['query']['backlinks'] += next_backlinks
    end

    result
  end

  def run_links(uri)
    json = open(uri.build_links).read
    result = JSON.parse(json)
    pages = result['query']['pages']
    pages.each do |id_string, page|
      plcontinue_s = plcontinue(id_string, result)
      unless plcontinue_s.nil?
        print '...'
        uri.continue = plcontinue_s
        next_result = run_links(uri)
        next_pages = next_result['query']['pages']
        next_pages.each do |_, next_page|
          page['links'] += next_page['links']
        end
        #page['links'].uniq!
      end
    end
    result
  end

  def blcontinue(result)
    begin
      blcontinue = result['query-continue']['backlinks']['blcontinue']
    rescue NoMethodError
      return nil
    end
    blcontinue
  end

  def plcontinue(id_string, result)
    begin
      plcontinue = result['query-continue']['links']['plcontinue']
    rescue NoMethodError
      return nil
    end
    unless plcontinue.nil?
      id = plcontinue.split('|')[0]
      if id == id_string
        return plcontinue
      end
    end
    nil
  end

  def backlinks_result_ok?(result)

    if result.nil?
      return false
    elsif result['query'].nil?
      return false
    elsif result['query']['backlinks'].nil?
      return false
    end

    if result['query']['backlinks'].length == 0
      return false
    end

    true
  end

  def links_result_ok?(result)

    if result.nil?
      return false
    elsif result['query'].nil?
      return false
    elsif result['query']['pages'].nil?
      return false
    end

    result['query']['pages'].each do |_, p|
      if p.nil?
        return false
      elsif p['title'].nil? || p['links'].nil?
        return false
      elsif p['pageid'].nil? || p['ns'].nil?
        return false
      end
    end
    true
  end

  public

  def get_backlink_titles(title)
    uri = UriHelper.new(title)
    result = nil
    3.times do
      puts
      print "Downloading backlinks for #{uri.title}..."
      begin
        result = run_backlinks(uri)
        break
      rescue SystemCallError => e
        puts e.class
      end
    end
    backlink_titles = Array.new
    if backlinks_result_ok?(result)
      puts 'done'
      result['query']['backlinks'].each do |backlink|
        if backlink.has_key?('redirect')
          redirlinks = backlink['redirlinks']
          unless redirlinks.nil?
            redirlinks.each do |redirlink|
              backlink_titles.push(redirlink['title'])
            end
          end
        else
          backlink_titles.push(backlink['title'])
        end
      end
      backlink_titles
    else
      puts 'no backlinks'
      backlink_titles
    end
  end

  def get_link_titles(title)
    uri = UriHelper.new(title)
    result = nil
    3.times do
      puts
      print "Downloading links for #{uri.title}..."
      begin
        result = run_links(uri)
        break
      rescue SystemCallError => e
        puts e.class
      end
    end
    link_titles = Array.new
    if links_result_ok?(result)
      puts 'done'
      result['query']['pages'].each do |_, page|
        page['links'].each do |link|
          link_titles.push(link['title'])
        end
      end
      link_titles
    else
      puts 'no links'
      link_titles
    end
  end

end
