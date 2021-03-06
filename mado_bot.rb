#!/usr/bin/ruby -Ku
require 'rubygems'
require "cgi"
require "dm-core"
require "dm-timestamps"
require 'oauth'
require 'pit'
require 'pp'
require 'twitter'

#DataMapper::Logger.new("/tmp/mado_out", :debug)

class Tweet
  include DataMapper::Resource

  property :id,        Serial
  property :status_id, String,  :required => true, :default => '', :length => 0..255
  property :name,      String,  :required => true, :default => '', :length => 0..255
  property :text,      String,  :required => true, :default => '', :length => 0..255
  property :opened,    Boolean, :required => true, :default => 0
  timestamps :at
end

class Mention
  include DataMapper::Resource

  property :id,        Serial
  property :status_id, String,  :required => true, :default => '', :length => 0..255
  property :name,      String,  :required => true, :default => '', :length => 0..255
  property :text,      String,  :required => true, :default => '', :length => 0..255
  property :retweeted, Boolean, :required => true, :default => 0
  timestamps :at
end

class MadoBot
  attr_accessor :tw, :search

  def init
    app_conf  = Pit.get('mado_bot')
    db_conf   = Pit.get('mado_bot_dsn')
    user_conf = Pit.get('mado_bot_user')

    Twitter.configure do |config|
      config.consumer_key       = app_conf["consumer_key"]
      config.consumer_secret    = app_conf["consumer_secret"]
      config.oauth_token        = user_conf["access_token"]
      config.oauth_token_secret = user_conf["access_token_secret"]
    end

    client = Twitter::Client.new
    self.tw = client
    self.search = Twitter::Search.new

    DataMapper.setup(:default, {
      :adapter  => db_conf["adaptor"],
      :database => db_conf["database"],
      :username => db_conf["username"],
      :password => db_conf["password"],
      :host     => db_conf["host"]
    })
  end

  def openable(twit)
    str = twit.text
    str =~ /窓/ or return nil
    user = twit.from_user || twit.user.screen_name
    post_text = "@" + user + " の窓を変更: " + twit.text.gsub('窓', '社会の窓')
    post_text = CGI.unescapeHTML(post_text)
    if post_text.split(//u).length < 140 and
      twit.from_user !~ /bot/i and
      twit.from_user != 'fx_fan_jp' and
      twit.from_user != 'abu_mustafa' and
      twit.from_user != 'take_cheeze' and
      twit.from_user != 'ko10buki' and
      twit.from_user != 'Hakui_no_Tak' and
      twit.from_user != '000ajiaji000' and
      twit.from_user != 'Moroboshi_Lum' and
      /windows06/ !~ str and
      /[一二三四五六七八九]窓/ !~ str and
      /ジョハリの窓/ !~ str and
      /[０-９]窓/ !~ str and
      /窓[０-９]/ !~ str and
      /窓[Bb]ot/  !~ str and
      /[\d+]窓/   !~ str and
      /窓ガラス/  !~ str and
      /ガラス窓/  !~ str and
      /バスの窓/  !~ str and
      /中東の窓/  !~ str and
      /部屋の窓/  !~ str and
      /世界の窓/  !~ str and
      /会社の窓/  !~ str and
      /社会の窓/  !~ str and
      /窓付き/    !~ str and
      /検索窓/    !~ str and
      /複数窓/    !~ str and
      /二重窓/    !~ str and
      /入力窓/    !~ str and
      /車の窓/    !~ str and
      /窓の杜/    !~ str and
      /窓の社/    !~ str and
      /窓さん/    !~ str and
      /窓たん/    !~ str and
      /同窓/      !~ str and
      /窓際/      !~ str and
      /内窓/      !~ str and
      /外窓/      !~ str and
      /円窓/      !~ str and
      /天窓/      !~ str and
      /高窓/      !~ str and
      /車窓/      !~ str and
      /新窓/      !~ str and
      /別窓/      !~ str and
      /多窓/      !~ str and
      /出窓/      !~ str and
      /窓口/      !~ str and
      /窓辺/      !~ str and
      /窓枠/      !~ str and
      /窓7/       !~ str and
      /小窓/      !~ str
      return post_text.gsub("\n", "")
    else
      return nil
    end
  end

  def stock_data
    self.search.lang('all').per_page(50).containing('窓').fetch.each do |twit|
      post_text = self.openable(twit)
      if post_text
        tweet = Tweet.first(:status_id => twit.id)

        if !tweet
          Tweet.create(:status_id => twit.id, :name => twit.from_user, :text => post_text)
          puts post_text
        end
      end
    end
  end

  def open_window
    #tweet = Tweet.get(id)
    tweet = Tweet.last(:opened => 0)
    if tweet
      puts tweet.text
      self.tw.update(tweet.text, {:in_reply_to_status_id => tweet.status_id})
      #self.tw.update(tweet.text)
      tweet.update(:opened => 1)
    end
  end

  def settle_relation
    friend_ids        = self.tw.friend_ids["ids"]
    follower_ids      = self.tw.follower_ids["ids"]
    friend_ids_hash   = {}
    follower_ids_hash = {}
    mix_ids      = {}

    friend_ids.each do |id|
      friend_ids_hash[id] = 1
      mix_ids[id] = 1
    end
    follower_ids.each do |id|
      follower_ids_hash[id] = 1
      mix_ids[id] = 1
    end

    mix_ids.each do |id, v|
      if !friend_ids_hash[id] and follower_ids_hash[id]
        begin
          puts "create #{id}"
          self.tw.friendship_create(id)
        rescue
        end
      elsif friend_ids_hash[id] and !follower_ids_hash[id]
        begin
          puts "destroy #{id}"
          self.tw.friendship_destroy(id)
        rescue
        end
      end
    end
  end

  def stock_mention
    self.tw.mentions({:count => 100, :page => 1}).each do |mention|
      return if mention.user['screen_name'] =~ /bot$/i
      tweet = Mention.first(:status_id => mention.id)

      if !tweet
        puts mention.text
        Mention.create(:status_id => mention.id, :name => mention.user['screen_name'], :text => CGI.unescapeHTML(mention.text.gsub("\n", "")))
      end
    end
  end

  def rt_mention
    mention = Mention.first(:order => [:status_id.desc], :retweeted => 0)
    if mention
      begin
        puts mention.text
        self.tw.retweet(mention.status_id)
      rescue
      end
      mention.update(:retweeted => 1)
    end
  end

  def stock_tweet(id)
    tweet = self.tw.status(id) or return
    post_text = self.openable(tweet)
    if post_text
        exist = Tweet.first(:status_id => tweet.id)

        if !exist
          user = tweet.user.screen_name
          Tweet.create(:status_id => tweet.id, :name => user, :text => post_text)
        end
    end
  end
end

mado = MadoBot.new
mado.init

mode = ARGV.shift || ''
if mode == "rel"
  mado.settle_relation
elsif mode == "stock"
  mado.stock_data
elsif mode == "hear"
  mado.stock_mention
elsif mode == "rt"
  mado.rt_mention
elsif mode =~ /^\d+$/
  mado.stock_tweet(mode)
elsif mode == "resetdb"
  DataMapper.auto_migrate!
else
  mado.open_window
end
