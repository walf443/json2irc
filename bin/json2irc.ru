#!/usr/bin/env rackup

$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__), 'lib'))

require 'json2irc'

run(JSON2IRC.new)
