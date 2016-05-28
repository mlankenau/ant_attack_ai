class Channel
  def self.connect(ws, name, payload)
    channel = new(ws, name)
    yield(channel)

    channel.ws_send(name, 'phx_join', payload)
    me = self
    ws.on :message do |msg|
      #puts "***** #{msg}"
      msg = JSON.parse(msg.data)
      if msg["topic"] == name
        begin
          event = msg['event']
          payload = msg['payload']
          channel.handle(event, DeepStruct.new(payload))
        rescue => e
          puts "#{e.class} #{e.message}, #{e.backtrace[0..100]}"
        end
      end
    end
  end

  def initialize(ws, topic)
    @ws = ws
    @topic = topic
    @handler = {}
  end

  def pause
    @pause = true
    yield
    @pause = false
  end

  def handle(event, payload)
    if @handler["on_#{event}".to_sym]
      @handler["on_#{event}".to_sym].call(payload)
    else
      puts "unhandled event #{@topic}.#{event} with payload #{payload}"
    end
  end

  def send(event, payload)
    ws_send(@topic, event, payload)
  end

  def ws_send(topic, event, payload)
    msg = {topic: topic, event: event, payload: payload, ref: next_ref.to_s}
    @ws.send(msg.to_json)
  end

  def method_missing(name, *args, &block)
    if name.to_s =~ /^on_/
      @handler[name] = block
    else
      puts "dont know #{name}"
      super(name, args, &block)
    end
  end

  def next_ref
    @next_ref ||= 0
    @next_ref += 1
  end
end
