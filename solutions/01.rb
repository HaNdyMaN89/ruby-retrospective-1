class Array
  def to_hash
    {}.tap do |hash|
      each { |el| hash[el[0]] = el[1] }
    end
  end

  def index_by(&block)
    zip(map(&block)).to_hash.invert
  end

  def subarray_count(sub_array)
    each_cons(sub_array.length).count(sub_array)    
  end

  def occurences_count
    Hash.new(0).tap do |hash|
      each { |el| hash[el] += 1 }
    end
  end
end
