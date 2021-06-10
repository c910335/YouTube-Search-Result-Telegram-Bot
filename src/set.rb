class Set
  def to_json(*args)
    to_a.to_json(*args)
  end
end
