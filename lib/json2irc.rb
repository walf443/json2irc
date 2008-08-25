require 'classx'
require 'json'
require 'thread'
require 'monitor'
require 'yaml'
require 'rack'
require 'uri'

class JSON2IRC
  include ClassX

  class Config
    include ClassX

    has :host, :kind_of => String
    has :port, :kind_of => Integer, :default => 6667
    has :nick, :kind_of => String
    has :user, :kind_of => String, :lazy => true, :default => proc {|mine| mine.nick }
    has :real, :kind_of => String, :lazy => true, :default => proc {|mine| mine.nick }
    has :channels, :kind_of => Array
  end

  module Connection
    autoload :IRC, 'json2irc/connection/irc'
  end

  # define attribute
  include ClassX::Role::Logger

  has :config_file,
    :kind_of => String,
    :optional => true,
    :default => File.expand_path(File.join(File.dirname(__FILE__), '..', 'config.yaml'))

  has :config,
    :kind_of  => Config,
    :no_cmd_option => true,
    :lazy     => true,
    :default  => proc {|mine|
        Config.new(YAML.load(File.open(mine.config_file).read))
    }

  def after_init
    logger.debug(self.config)

    @irc = Connection::IRC.new(self.config.host, self.config.port, {
      "nick"    => self.config.nick,
      "user"    => self.config.user,
      "real"    => self.config.nick,
      "logger"  => self.logger,
    })
    Thread.new do
      @irc.connect(self.config.channels)
      logger.info('starting irc connection')
    end
  end

  class Forbidden < Exception; end

  def call env
    req = Rack::Request.new(env)

    raise Forbidden unless req.params['json']

    json = JSON.parse(req.params['json']) or
      raise Forbidden
    logger.debug(json)
    msg    = json['message'] or
      raise Forbidden
    method = json['method'] or
      raise Forbidden
    channel = json['channel'] or
      raise Forbidden

    unless self.config.channels.include?("##{channel}")
      raise Forbidden
    end

    unless @irc.queue.nil?
      @irc.queue = []
      @irc.queue.extend(MonitorMixin)
    end
    @irc.queue.synchronize do
      @irc.queue.push(:message => msg, :method => method, :channel => "##{channel}") 
    end

    return [ 200, {'Content-Type' => 'text/plain'}, '200 OK' ]
  rescue Forbidden
    return [ 403, {'Content-Type' => 'text/plain'}, '403 FORBIDDEN' ]
  end
end
