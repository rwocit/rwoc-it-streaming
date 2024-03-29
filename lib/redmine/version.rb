require 'rexml/document'

module Redmine
  module VERSION #:nodoc:
    MAJOR = 2
    MINOR = 1
    TINY  = 3

    # Branch values:
    # * official release: nil
    # * stable branch:    stable
    # * trunk:            devel
    BRANCH = 'stable'

    def self.revision
      revision = nil
      entries_path = "#{Rails.root}/.svn/entries"
      if File.readable?(entries_path)
        begin
          f = File.open(entries_path, 'r')
          entries = f.read
          f.close
          if entries.match(%r{^\d+})
            revision = $1.to_i if entries.match(%r{^\d+\s+dir\s+(\d+)\s})
          else
            xml = REXML::Document.new(entries)
            revision =
              xml.elements['wc-entries'].elements[1].attributes['revision'].to_i
          end
        rescue
          # Could not find the current revision
        end
      end
      revision
    end

    REVISION = self.revision
    ARRAY    = [MAJOR, MINOR, TINY, BRANCH, REVISION].compact
    STRING   = ARRAY.join('.')

    def self.to_a; ARRAY  end
    def self.to_s; STRING end
  end
end
