#!/usr/bin/env ruby
require 'rubygems'
require 'bundler/setup'
require 'json'
require 'telegram/bot'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'google/apis/youtube_v3'
require 'active_support/core_ext/numeric/time'
require './config'
require './src/set'
require './src/youtube/video'
require './src/youtube/channel'
require './src/youtube'
require './src/bot'

Bot.start
