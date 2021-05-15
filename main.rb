#!/usr/bin/env ruby
require 'rubygems'
require 'bundler/setup'
require 'telegram/bot'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'google/apis/youtube_v3'
require 'active_support/core_ext/numeric/time'
require './config'
require './src/youtube'
require './src/youtube/video'
require './src/bot'

Bot.start
