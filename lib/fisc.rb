require 'open-uri'
require 'nokogiri'

require './lib/alerts'
require './lib/git'
require './lib/filings'

module FISC
  URL = "http://www.fisc.uscourts.gov/public-filings"

  def self.config
    @config ||= YAML.load(File.read('config.yml'))
  end

  # use the "last" link to figure out the final page #
  # pretty brittle: it'd better be there
  def self.last_page!
    puts "Finding page number of final page..."
    first = download! FISC::Filings.url_for(page: 1)
    doc = Nokogiri::HTML first
    link = doc.at("li.pager-last").at("a")['href']
    page = link.scan(/page=(\d+)/).first.first.to_i
    puts "Last page: #{page}"
    page
  end


  def self.download!(url)
    # puts "Downloading: #{url}"
    open(
      url,
      "User-Agent" => "@FISACourt, twitter.com/FISACourt, github.com/konklone/fisacourt"
    ).read
  end

  def self.check!(options: {})
    return "test" if options[:test]

    pages = options[:archive] ? (1..last_page!).to_a : [1]

    pages.each do |page|
      puts "[#{page}] Downloading filings..."
      if options[:use_file]
        body = File.read "./test/filings#{page}.html"
      else
        url = FISC::Filings.url_for page: page
        body = download! url
      end

      # parse filing data out of the HTML
      filings = FISC::Filings.for_page body

      puts filings

      # save a .yml file for each one into the docket dir
      # filings.each do |filing|
      #   FISC::Filings.save! filing
      # end
    end

    puts "Saved current state of FISC docket."

    if FISC::Git.changed? or options[:test_error]
      begin
        raise Exception.new("Fake git error!") if test_error
        FISC::Git.save! "FISC dockets have been updated"

      rescue Exception => ex
        puts "Error doing the git commit and push! #{ex.inspect}"
        FISC::Alerts.admin! "Git error!"
        true
      end
    else
      false
    end

  end
end
