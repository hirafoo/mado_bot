#!/usr/bin/ruby -Ku
require 'rubygems'
require "dm-core"
require "dm-timestamps"
require 'oauth'
require 'pit'
require 'pp'
require 'twitter'

class Tweet
  include DataMapper::Resource

  property :id,        Serial
  property :status_id, String,  :required => true, :default => '', :length => 0..255
  property :name,      String,  :required => true, :default => '', :length => 0..255
  property :text,      String,  :required => true, :default => '', :length => 0..255
  property :opened,    Boolean, :required => true, :default => 0
  timestamps :at
end

class MadoBot
  attr_accessor :tw, :search

  def init
    app_conf  = Pit.get('mado_bot')
    db_conf   = Pit.get('mado_bot_dsn')
    user_conf = Pit.get('mado_bot_user')

    oauth = Twitter::OAuth.new(app_conf["consumer_key"], app_conf["consumer_secret"])
    oauth.authorize_from_access(user_conf["access_token"], user_conf["access_token_secret"])

    self.tw = Twitter::Base.new(oauth)
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
    post_text = "@" + twit.from_user + " の窓を変更: " + twit.text.gsub('窓', '社会の窓')
    if post_text.split(//u).length < 140 and
      twit.from_user !~ /[Bb]ot/i and
      twit.from_user != 'fx_fan_jp' and
      /[０１２３４５６７８９]窓/ !~ str and
      /窓[０１２３４５６７８９]/ !~ str and
      /[一二三四五六七八九]窓/   !~ str and
      /窓[Bb]ot/  !~ str and
      /[\d+]窓/   !~ str and
      /窓ガラス/  !~ str and
      /バスの窓/  !~ str and
      /中東の窓/  !~ str and
      /部屋の窓/  !~ str and
      /会社の窓/  !~ str and
      /世界の窓/  !~ str and
      /社会の窓/  !~ str and
      /窓付き/    !~ str and
      /同窓会/    !~ str and
      /検索窓/    !~ str and
      /複数窓/    !~ str and
      /二重窓/    !~ str and
      /入力窓/    !~ str and
      /車の窓/    !~ str and
      /窓の杜/    !~ str and
      /窓の社/    !~ str and
      /窓さん/    !~ str and
      /窓際/      !~ str and
      /内窓/      !~ str and
      /外窓/      !~ str and
      /天窓/      !~ str and
      /高窓/      !~ str and
      /車窓/      !~ str and
      /新窓/      !~ str and
      /別窓/      !~ str and
      /多窓/      !~ str and
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
    self.search.containing('窓').fetch.results.each do |twit|
      post_text = self.openable(twit)
      if post_text
        tweet = Tweet.first(:status_id => twit.id)

        if !tweet
          Tweet.create(:status_id => twit.id, :name => twit.from_user, :text => post_text)
        end
      end
    end
  end

  def open_window
    tweet = Tweet.last(:opened => 0)
    if tweet
      puts tweet.text
      self.tw.update(tweet.text, {:in_reply_to_status_id => tweet.status_id})
      #self.tw.update(tweet.text)
      tweet.update(:opened => 1)
    end
  end

  def settle_relation
    friend_ids        = self.tw.friend_ids
    follower_ids      = self.tw.follower_ids
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
end

mado = MadoBot.new
mado.init
mado.settle_relation
mado.stock_data
mado.open_window
