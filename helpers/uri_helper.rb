require 'cgi'

#MediaWiki version 1.9
class UriHelper
  BASE = 'http://en.wikipedia.org/w/api.php?'
  ACTION = 'action='
  TITLES = 'titles='
  BLTITLE = 'bltitle='
  PROP = 'prop='
  LIST = 'list='
  PLNAMESPACE = 'plnamespace='
  BLNAMESPACE = 'blnamespace='
  PLLIMIT = 'pllimit='
  BLLIMIT = 'bllimit='
  FORMAT = 'format='
  PLCONTINUE = 'plcontinue='
  BLCONTINUE = 'blcontinue='

  private

  def initialize(title)
    @action = 'query'
    @prop = 'links'
    @list = 'backlinks'

    @title = title
    @namespace = '0'
    @limit = 500
    @format = 'json'
    @continue = nil
  end

  def enc(string)
    CGI.escape(string)
  end

  public

  def title
    @title
  end

  def title=(title)
    @title = title
  end

  def continue=(continue)
    @continue = continue
  end

  def build_backlinks
    uri = BASE
    uri += ACTION + enc(@action)
    uri += '&'
    uri += BLTITLE + enc(@title)
    uri += '&'
    uri += LIST + enc(@list)
    uri += '&'
    uri += BLNAMESPACE + enc(@namespace)
    uri += '&'
    uri += BLLIMIT + enc(@limit.to_s)
    uri += '&'
    uri += FORMAT + enc(@format)

    unless @continue.nil?
      uri+= '&'
      uri+= BLCONTINUE + enc(@continue)
    end

    uri += '&blredirect'

    uri
  end

  def build_links
    uri = BASE
    uri += ACTION + enc(@action)
    uri += '&'
    uri += TITLES + enc(@title)
    uri += '&'
    uri += PROP + enc(@prop)
    uri += '&'
    uri += PLNAMESPACE + enc(@namespace)
    uri += '&'
    uri += PLLIMIT + enc(@limit.to_s)
    uri += '&'
    uri += FORMAT + enc(@format)

    unless @continue.nil?
      uri+= '&'
      uri+= PLCONTINUE + enc(@continue)
    end

    uri += '&redirects'

    uri
  end
end
