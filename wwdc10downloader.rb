# Have fun. Use at your own risk.

require 'rubygems'
require 'mechanize'
require 'json'
require 'ftools'
require 'net/http'

puts "WWDC 2010 Session Material Downloader"
puts "by Johannes Fahrenkrug, springenwerk.com"
puts "See you next year!"
puts

if ARGV.size < 2
  puts "Usage: ruby wwdc2010downloader.rb <your Apple ID> <your ADC Password>"
  exit
end

base_uri = 'https://developer.apple.com/wwdc/scripts/services.php?format=json&type='
dl_dir = 'wwdc2010-assets'

# Creates the given directory if it doesn't exist already.
def mkdir(dir)
  Dir.mkdir dir unless File.exists?(dir)
end

# create dir
mkdir(dl_dir)

a = Mechanize.new

# Login
a.get(base_uri + 'docs&session=1') do |page|
  my_page = page.form_with(:name => 'appleConnectForm') do |f|
    f.theAccountName  = ARGV[0]
    f.theAccountPW = ARGV[1]
  end.click_button
end

(1..520).each do |session|
  print "Trying session #{session}..."
  
  success = false
  title = nil
  
  # get the title  
  a.get("#{base_uri}all&session=#{session}") do |page|
    res = JSON.parse(page.body)
    sessions = res['response']['sessions']
    if sessions.size > 0
      success = true
      title = sessions[0]['title']
      print title + "\n"
    else
      print "Nope.\n"
    end
  end
  
  # get the files
  if success
    dirname = "wwdc2010-assets/#{session}-#{title.gsub(/\/|&|!/, '')}" 
    puts "  Creating #{dirname}"
    mkdir(dirname)
    a.get("#{base_uri}docs&session=#{session}") do |page|
      res = JSON.parse(page.body)
      docs = res['response']['docs']
      docs.each do |doc|
        doc[session.to_s]['documents'].each do |actual_doc|
          actual_doc['files'].each do |file|
            # only zip files and pdfs
            doc_path = file['document_url']
            if doc_path =~ /\.(pdf)|\.(zip)$/
              filename = File.basename(doc_path)
              ref_lib = file["reference_library"]
              url = (ref_lib == 'iad' ? 'iphone/iad' : ref_lib) + "/library/" + doc_path
              puts "  Downloading #{url}"
              begin
                a.get("https://developer.apple.com/wwdc/#{url}") do |downloaded_file|
                  open(dirname + "/" + filename, 'wb') do |file|
                    file.write(downloaded_file.body)
                  end
                end
              rescue Exception => e
                puts "  Download failed #{e}"
              end
            end
          end
        end
      end
    end
  end
end

puts "Done."

