class YouTube::Video
  attr_reader :id, :title, :channel

  def initialize(id, title, channel)
    @id = id
    @title = title
    @channel = channel
  end

  def url
    "https://youtu.be/#{id}"
  end

  def eql?(other)
    id == other.id
  end

  def hash
    id.hash
  end
end
