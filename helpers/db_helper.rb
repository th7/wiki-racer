require 'sqlite3'

class DbHelper

  private

  require_here 'web_helper'

  def initialize(filename)
    @filename = filename

    begin
      @db = SQLite3::Database.new(@filename)
      @db.execute 'PRAGMA foreign_keys = ON'
      @db.execute 'CREATE TABLE IF NOT EXISTS pages(_id INTEGER PRIMARY KEY NOT NULL, title TEXT NOT NULL COLLATE NOCASE, have_links INTEGER NOT NULL DEFAULT 0, have_backlinks INTEGER NOT NULL DEFAULT 0,UNIQUE(title))'
      @db.execute 'CREATE TABLE IF NOT EXISTS links(page INTEGER NOT NULL, link INTEGER NOT NULL, PRIMARY KEY(page, link), FOREIGN KEY(page) REFERENCES pages(_id) ON DELETE CASCADE, FOREIGN KEY(link) REFERENCES pages(_id) ON DELETE CASCADE)'
      @db.execute 'CREATE INDEX IF NOT EXISTS links_index ON links(link)'
    rescue SQLite3::BusyException
      retry
    end

    @web = WebHelper.new
    @show_activity_counter = 0
    #up
    #vacuum
  end

  def select_backlink_ids(page_id)
    @db.prepare('SELECT page FROM links WHERE link = ?') do |stmt|
      stmt.execute(page_id) do |result|
        backlink_ids = Array.new
        result.each do |r|
          backlink_ids.push(r[0])
        end
        return backlink_ids
      end
    end
  end

  def select_link_ids(page_id)
    @db.prepare('SELECT link FROM links WHERE page = ?') do |stmt|
      stmt.execute(page_id) do |result|
        link_ids = Array.new
        result.each do |r|
          link_ids.push(r[0])
        end
        return link_ids
      end
    end
  end

  def select_ids(titles)
    ids = Array.new
    unless titles.nil?
      @db.prepare('SELECT _id FROM pages WHERE title = ?') do |stmt|
        titles.each do |title|
          stmt.execute(title) do |result|
            result.each do |r|
              ids.push(r[0])
            end
          end
        end
      end
    end
    ids
  end

  def insert_pages(titles)
    start

    @db.prepare('INSERT OR IGNORE INTO pages(title) VALUES(?)') do |stmt|
      titles.each do |title|
        stmt.execute(title)
      end
    end
    commit

  end

  def insert_backlinks(page_id, backlink_ids)
    start
    @db.execute "UPDATE pages SET have_backlinks = 1 WHERE _id = #{page_id.to_s}"
    @db.prepare('INSERT OR IGNORE INTO links(page, link) VALUES(?,?)') do |stmt|
      backlink_ids.each do |backlink_id|
        stmt.execute(backlink_id, page_id) unless page_id == backlink_id
      end
    end
    commit

  end

  def insert_links(page_id, link_ids)
    start
    @db.execute "UPDATE pages SET have_links = 1 WHERE _id = #{page_id.to_s}"
    @db.prepare('INSERT OR IGNORE INTO links(page, link) VALUES(?,?)') do |stmt|
      link_ids.each do |link_id|
        stmt.execute(page_id, link_id) unless page_id == link_id
      end
    end
    commit

  end


  def have_backlinks?(id)
    @db.prepare('SELECT have_backlinks FROM pages WHERE _id = ?') do |stmt|
      stmt.execute(id) do |result|
        result.each do |r|
          return true if r[0] == 1
        end
      end
    end

    false
  end

  def have_links?(id)
    @db.prepare('SELECT have_links FROM pages WHERE _id = ?') do |stmt|
      stmt.execute(id) do |result|
        result.each do |r|
          return true if r[0] == 1
        end
      end
    end

    false
  end

  def show_activity
    @show_activity_counter += 1
    if @show_activity_counter > 10
      print '.'
      @show_activity_counter = 0
    end
  end

  def open
    if @db.closed?
      @db = SQLite3::Database.open(@filename)
      #@db.execute 'PRAGMA foreign_keys = ON'
      #@db.execute 'PRAGMA cache_size = 10000'
      #@db.execute 'PRAGMA journal_mode = WAL'
    end

  end

  def close
    @db.close unless @db.closed?
  end

  def start
    @db.rollback if @db.transaction_active?
    @db.transaction
  end

  def commit
    @db.commit
  end

  public

  def vacuum
    open
    puts 'Vacuuming DB'
    @db.execute 'VACUUM'
    puts 'done'
    close
  end

  def up
    open
    puts 'Adjusting table(s) -- press enter to proceed or ctrl+c to cancel'
    gets

    @db.execute 'PRAGMA journal_mode = OFF'
    @db.execute 'PRAGMA synchronous = OFF'
    @db.execute 'PRAGMA foreign_keys = OFF'

    start
    puts 'renaming pages to temp_pages'
    @db.execute 'ALTER TABLE pages RENAME TO temp_pages'
    puts 'creating new pages table'
    @db.execute 'CREATE TABLE IF NOT EXISTS pages(_id INTEGER PRIMARY KEY NOT NULL, title TEXT NOT NULL COLLATE NOCASE, have_links INTEGER NOT NULL DEFAULT 0, have_backlinks INTEGER NOT NULL DEFAULT 0,UNIQUE(title))'

    puts 'renaming links to temp_links'
    @db.execute 'ALTER TABLE links RENAME TO temp_links'
    puts 'creating new links table'
    @db.execute 'CREATE TABLE IF NOT EXISTS links(page INTEGER NOT NULL, link INTEGER NOT NULL, PRIMARY KEY(page, link), FOREIGN KEY(page) REFERENCES pages(_id) ON DELETE CASCADE, FOREIGN KEY(link) REFERENCES pages(_id) ON DELETE CASCADE)'

    puts 'inserting old values from temp_pages into pages'
    @db.execute 'INSERT OR IGNORE INTO pages(_id, title, have_links, have_backlinks) SELECT _id, title, have_links, have_backlinks FROM temp_pages'

    puts 'inserting old values from temp_links into links'
    @db.execute 'INSERT OR IGNORE INTO links(page, link) SELECT page, link FROM temp_links'
    puts 'indexing links column'
    @db.execute 'CREATE INDEX IF NOT EXISTS links_index ON links(link)'

    puts 'dropping temp_links'
    @db.execute 'DROP TABLE temp_links'
    puts 'dropping temp_pages'
    @db.execute 'DROP TABLE temp_pages'
    puts 'committing changes'
    commit

    @db.execute 'PRAGMA foreign_keys = ON'
    @db.execute 'PRAGMA synchronous = ON'
    @db.execute 'PRAGMA journal_mode = WAL'
    puts 'done'
    gets
    close
  end

  def get_link_ids(id)
    begin
      open
      if have_links?(id)
        show_activity
        link_ids = select_link_ids(id)
      else
        title = get_titles([id])[0]
        open
        link_titles = @web.get_link_titles(title)
        insert_pages(link_titles)
        link_ids = select_ids(link_titles)
        insert_links(id, link_ids)
      end
      close
      return link_ids
    rescue SQLite3::BusyException
      retry
    end
  end

  def get_backlink_ids(id)
    begin
      open

      if have_backlinks?(id)
        show_activity
        backlink_ids = select_backlink_ids(id)
      else
        title = get_titles([id])[0]
        open
        backlink_titles = @web.get_backlink_titles(title)
        insert_pages(backlink_titles)
        backlink_ids = select_ids(backlink_titles)
        insert_backlinks(id, backlink_ids)
      end
      close
      return backlink_ids
    rescue SQLite3::BusyException
      retry
    end
  end

  def get_id(title)
    begin
      open
      id = select_ids([title])[0]
      if id.nil?
        insert_pages([title])
        id = select_ids([title])[0]
      end
      close
      return id
    rescue SQLite3::BusyException
      retry
    end
  end

  def get_titles(ids)
    begin
      titles = Array.new
      unless ids.nil?
        open
        @db.prepare('SELECT title FROM pages WHERE _id = ?') do |stmt|
          ids.each do |id|
            stmt.execute(id) do |result|
              result.each do |r|
                titles.push(r[0])
              end
            end
          end
        end
        close
      end
      return titles
    rescue SQLite3::BusyException
      retry
    end
  end

  def show_status
    open
    begin
      puts(@db.execute('SELECT COUNT(*) FROM pages')[0][0].to_s + ' pages in db')
      puts(@db.execute('SELECT COUNT(*) FROM links')[0][0].to_s + ' links/backlinks in db')
    rescue SQLite3::BusyException
      retry
    end
    close
  end
end
