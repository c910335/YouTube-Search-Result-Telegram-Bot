class YouTube
  class Video
    attr_reader :id, :title, :channel_id, :channel_title, :duration

    def initialize(id, title, channel_id, channel_title, duration)
      @id = id
      @title = title
      @channel_id = channel_id
      @channel_title = channel_title
      @duration = duration
    end

    def url
      "https://youtu.be/#{id}"
    end

    def to_json(*args)
      {
        id: id,
        title: title,
        channel_id: channel_id,
        channel_title: channel_title,
        duration: duration
      }.to_json(*args)
    end

    def to_s
      "#{title} (#{id})"
    end

    def eql?(other)
      id == other.id
    end

    def hash
      id.hash
    end
  end
end
