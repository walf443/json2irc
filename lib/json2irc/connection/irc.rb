require 'net/irc'

module JSON2IRC::Connection
  class IRC < ::Net::IRC::Client
    class MethodNotAllowed < Exception; end

    attr_accessor :queue

    def connect channels
      channels.each do |channel|
        init_channel(channel)
      end
      start
    end

    # start session
    def on_rpl_endofmotd message
      @channels.keys.each do |channel|
        post JOIN, channel
      end
    end

    # just posting message
    def on_message message
      if @queue.nil?
        @queue = []
        @queue.extend(MonitorMixin)
      elsif @queue.size > 0
        while ( @queue.size > 0 )
          @queue.synchronize do
            msg = @queue.pop
            method = nil
            if msg[:method]
              method = 
                case msg[:method] 
                when "privmsg"
                  PRIVMSG
                when "notice"
                  NOTICE
                end
            else
              raise MethodNotAllowed
            end

            post(method, msg[:channel], msg[:message])
          end
        end
      end

      false
    end
  end
end
