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
  property :opened,    Serial,  :required => true, :default => 0
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
    post_text = ".@" + twit.from_user + " の危ない発言: " + twit.text.gsub('窓', '社会の窓')
    if post_text.split(//u).length < 140 and
      twit.from_user != 'mado_bot' and
      /窓/        =~ str and
      /[０１２３４５６７８９]窓/ !~ str and
      /窓[０１２３４５６７８９]/ !~ str and
      /[一二三四五六七八九]窓/   !~ str and
      /[\d+]窓/   !~ str and
      /窓ガラス/  !~ str and
      /バスの窓/  !~ str and
      /部屋の窓/  !~ str and
      /会社の窓/  !~ str and
      /世界の窓/  !~ str and
      /社会の窓/  !~ str and
      /窓付き/    !~ str and
      /同窓会/    !~ str and
      /検索窓/    !~ str and
      /入力窓/    !~ str and
      /車の窓/    !~ str and
      /窓の杜/    !~ str and
      /窓際/      !~ str and
      /別窓/      !~ str and
      /窓口/      !~ str and
      /窓辺/      !~ str and
      /窓枠/      !~ str and
      /窓7/       !~ str and
      /小窓/      !~ str
      return post_text
    else
      return nil
    end
  end

  def stock_data
    self.search.containing('窓').fetch.results.each do |twit|
      puts twit.text
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
      #self.tw.update(tweet.text, {:in_reply_to_status_id => tweet.status_id})
      self.tw.update(tweet.text)
      tweet.update(:opened => 1)
    end
  end
end

mado = MadoBot.new
mado.init
mado.stock_data
mado.open_window
