class Song
  attr_reader :name, :artist, :genre, :subgenre, :tags

  def initialize(name, artist, genre, subgenre, tags)
    @name = name
    @artist = artist
    @genre = genre
    @subgenre = subgenre
    @tags = tags
  end

  def is_desired?(criteria)
    return false unless includes_tags?(criteria)
    return false if criteria.include? :name and @name != criteria[:name]
    return false if criteria.include? :artist and @artist != criteria[:artist]
    return false if criteria.include? :filter and not criteria[:filter][self]
    true
  end

  def includes_tags?(criteria)
    if criteria.include? :tags
      [criteria[:tags]].flatten.all? { |tag| has_tag? tag }
    else
      true
    end
  end

  def has_tag?(tag)
    tag.end_with?("!") ^ @tags.include?(tag.chomp "!")
  end
end

class Collection
  def initialize(songs_as_string, artist_tags)
    song_lines = songs_as_string.lines.select(&:strip)
    @songs = song_lines.collect { |line| parse_song(line, artist_tags) }
  end

  def parse_song(song_string, artist_tags)
    attrs = song_string.split(".").collect(&:strip)
    genre_sub = attrs[2].split(",").collect(&:strip)
    genre, subgenre = genre_sub
    tags = genre_sub.collect(&:downcase)
    tags |= artist_tags[attrs[1]] if artist_tags.include? attrs[1]
    tags |= attrs[3].split(",").collect(&:strip) if attrs.length > 3
    Song.new(attrs[0], attrs[1], genre, subgenre, tags)
  end

  def find(criteria)
    @songs.select { |song| song.is_desired? criteria }
  end
end
