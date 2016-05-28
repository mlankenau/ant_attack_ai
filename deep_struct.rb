class DeepStruct
  def initialize(hash)
    @hash = hash
  end

  def method_missing(name, *args, &block)
    val = @hash[name] || @hash[name.to_s]
    if val
      if val.is_a?(Hash)
        DeepStruct.new(val)
      else
        val
      end
    else
      raise "unknown field #{name}, having only #{@hash.keys}"
    end
  end

  def to_s
    @hash.to_s
  end
end
