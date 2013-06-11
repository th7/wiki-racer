require 'ruby-prof'
require 'cgi'
require 'find'

MAIN = Dir.pwd

def require_here(filename, search_in=MAIN)
  filename.insert(0, '/') unless filename[0] == '/'

  Find.find(search_in) do |path|
    return eval(File.new(path).read) if path =~ Regexp.new(filename + '(\.|\z)')
  end

  raise ArgumentError.new('could not find filename: ' + filename)
end

class Main

  private

  require_here 'search_helper'

  def initialize
    start
  end

  def Main.ask
    input = gets.chomp
    if input.downcase == 'exit'
      exit
    end
    input
  end

  def start
    puts
    puts 'Enter "exit" at any prompt to quit'
    puts
    while true
      search
    end
  end

  def search

    puts 'Starting article:'
    start_page = choose_page

    puts 'Ending article:'
    end_page = choose_page

    search = SearchHelper.new(start_page, end_page)
    puts
    puts 'Press ctrl+c to interrupt search'
    puts '. = 10 database items accessed, ! = 100k items accessed from memory'
    puts
    result = search.run

    puts
    puts
    puts 'Holy crap, a result!'
    puts
    puts result.inspect
    puts

  end

  def choose_page
    puts 'Enter a title or rand41'
    while true
      if $use_rand
        page = 'rand41'
      else
        page = Main.ask
      end

      if page == 'rand41'
        page = get_random_page
        unless page.nil?
          puts 'using ' + page
          return page
        else
          next
        end
      else
        page = check_page(page)
        unless page.nil?
          puts 'found ' + page
          return page
        else
          puts 'not found'
        end
      end
    end
  end

  def get_random_page
    uri = 'http://en.wikipedia.org/w/api.php?action=query&list=random&rnlimit=1&rnnamespace=0&format=json'

    result = nil
    3.times do
      print "Getting random page..."
      begin
        json = open(uri).read
        result = JSON.parse(json)
        break
      rescue SystemCallError => e
        puts e.class
      end
    end

    begin
      return result['query']['random'].first['title']
    rescue
      puts 'failed to find random page'
      nil
    end
  end

  def check_page(title)
    uri = "http://en.wikipedia.org/w/api.php?action=query&titles=#{CGI.escape(title)}&redirects&format=json"

    result = nil
    3.times do
      print "Checking #{title}..."
      begin
        json = open(uri).read
        result = JSON.parse(json)
        break
      rescue SystemCallError => e
        puts e.class
      end
    end
    begin

      query = result['query']
      query['pages'].each do |page_id, page|
        return nil if page_id.to_i <= 0
        return page['title']
      end

        #puts 'exists'
        #return true
    rescue NoMethodError
      # do nothing
    rescue TypeError
      # do nothing
    end
    #puts 'not found'
    nil
  end

end

$profile = false
$use_rand = true

begin
  RubyProf.start if $profile
  Main.new
ensure
  if $profile && RubyProf.running?
    report = RubyProf.stop
    printer = RubyProf::GraphHtmlPrinter.new(report)
    printer.print(File.new('report.html', 'w+'))
  end
end
