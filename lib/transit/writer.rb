require 'oj'
require 'msgpack'

module Transit
  class Marshaler
    extend Forwardable
    def_delegators :@emitter, :emit_array_start, :emit_array_end, :emit_map_start, :emit_map_end, :emit_object, :flush

    def initialize(emitter, opts={})
      @emitter = emitter
      @opts = opts
      @handlers = Handler.new
    end

    def register(type, handler_class)
      @handlers[type] = handler_class.new
    end

    def escape(s)
      return s if [nil, true, false].include? s
      [ESC, SUB, RES].include?(s[0]) ? "#{ESC}#{s}" : s
    end

    def emit_nil(_, as_map_key, cache)
      as_map_key ? emit_string(ESC, "_", nil, true, cache) : emit_object(nil)
    end

    def emit_string(prefix, tag, string, as_map_key, cache)
      str = "#{prefix}#{tag}#{escape(string)}"
      if cache.cacheable?(str, as_map_key)
        emit_object(cache.encode(str, as_map_key), as_map_key)
      else
        emit_object(str, as_map_key)
      end
    end

    def emit_boolean(b, as_map_key, cache)
      as_map_key ? emit_string(ESC, "?", b, true, cache) : emit_object(b)
    end

    def emit_quoted(o, as_map_key, cache)
      emit_map_start(1)
      emit_string(TAG, "'", nil, true, cache)
      marshal(o, false, cache)
      emit_map_end
    end

    MAX_INT = 2**53 - 1

    def emit_int(i, as_map_key, cache)
      if as_map_key || i > MAX_INT
        emit_string(ESC, "i", i.to_s, as_map_key, cache)
      else
        emit_object(i, as_map_key)
      end
    end

    def emit_double(d, as_map_key, cache)
      as_map_key ? emit_string(ESC, "d", d, true, cache) : emit_object(d)
    end

    def emit_array(a, _, cache)
      emit_array_start(a.size)
      a.each {|e| marshal(e, false, cache)}
      emit_array_end
    end

    def emit_map(m, _, cache)
      emit_map_start(m.size)
      m.each do |k,v|
        marshal(k, true, cache)
        marshal(v, false, cache)
      end
      emit_map_end
    end

    def emit_tagged_map(tag, rep, _, cache)
      emit_map_start(1)
      emit_object("#{ESC}##{tag}", true)
      marshal(rep, false, cache)
      emit_map_end
    end

    def emit_encoded(tag, obj, as_map_key, cache)
      if tag
        handler = @handlers[obj]
        if String === rep = handler.rep(obj)
          emit_string(ESC, tag, rep, as_map_key, cache)
        else
          emit_tagged_map(tag, rep.rep, false, cache)
        end
      end
    end

    def marshal(obj, as_map_key, cache)
      handler = @handlers[obj]
      tag = handler.tag
      rep = as_map_key ? handler.string_rep(obj) : handler.rep(obj)
      case tag
      when "s"
        emit_string(nil, nil, rep, as_map_key, cache)
      when "'"
        emit_quoted(rep, as_map_key, cache)
      when "i"
        emit_int(rep, as_map_key, cache)
      when "d"
        emit_double(rep, as_map_key, cache)
      when "_"
        emit_nil(rep, as_map_key, cache)
      when "?"
        emit_boolean(rep, as_map_key, cache)
      when :array
        emit_array(rep, as_map_key, cache)
      when :map
        emit_map(rep, as_map_key, cache)
      else
        emit_encoded(tag, obj, as_map_key, cache)
      end
    end

    def marshal_top(obj, cache)
      handler = @handlers[obj]
      if tag = handler.tag
        if @opts[:quote_scalars] && tag.length == 1
          marshal(Quote.new(obj), false, cache)
        else
          marshal(obj, false, cache)
        end
        flush
      end
    end
  end

  class Writer
    def initialize(io, type)
      @marshaler = if type == :json
                     Marshaler.new(JsonEmitter.new(io), :quote_scalars => true)
                   else
                     Marshaler.new(MessagePackEmitter.new(io), :quote_scalars => false)
                   end
    end

    def write(obj)
      @marshaler.marshal_top(obj, RollingCache.new)
    end

    def register(type, handler_class)
      @marshaler.register(type, handler_class)
    end
  end
end
