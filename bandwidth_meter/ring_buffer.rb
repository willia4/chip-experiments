# https://gist.github.com/Nimster/4078106

class RingBuffer < Array 
  attr_reader :max_size

  def initialize(max_size)
    @max_size = max_size
    max_size.times { self << 0 }
  end

  def <<(el)
    if self.size < @max_size
      super
    else
      self.shift
      self.push(el)
    end
  end

  def sum
    return self.inject(0) { |sum, el| sum + el }
  end

  def mean 
    return self.sum / @max_size
  end

  alias :push :<<
end