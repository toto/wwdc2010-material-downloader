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
  puts "Usage: ruby wwdc2010downloader.rb <your Apple ID> <your ADC Password> [<target-dir>]"
  exit
end

BASE_URI = 'https://developer.apple.com/wwdc/scripts/services.php?format=json&type='

$dl_dir = if ARGV.size > 2 
  ARGV.last
else
  'wwdc2010-assets'
end

# Creates the given directory if it doesn't exist already.
def mkdir(dir)
  Dir.mkdir dir unless File.exists?(dir)
end

def dl_session(session)
  cpid = Process.fork
  
  return if cpid
  
  print "Trying session #{session}..."
  
  success = false
  title = nil
  
  # get the title  
  $a.get("#{BASE_URI}all&session=#{session}") do |page|
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
    dirname = "#{$dl_dir}/#{session}-#{title.gsub(/\/|&|!/, '')}" 
    puts "  Creating #{dirname}"
    mkdir(dirname)
    $a.get("#{BASE_URI}docs&session=#{session}") do |page|
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
                $a.get("https://developer.apple.com/wwdc/#{url}") do |downloaded_file|
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

  exit(0)
end

# create dir
mkdir($dl_dir)

$a = Mechanize.new

puts "Login…"

# Login
$a.get(BASE_URI + 'docs&session=1') do |page|
  my_page = page.form_with(:name => 'appleConnectForm') do |f|
    f.theAccountName  = ARGV[0]
    f.theAccountPW = ARGV[1]
  end.click_button
end

$ids_to_dl = (1..520).to_a
MAX_CHILDREN = 5
$child_count = 0
$should_terminate = false

$ids_to_dl.each do |id|
  if $child_count >= MAX_CHILDREN
    Process.wait #(-1, Process::WNOHANG)  
    $child_count -= 1
    puts "Download for #{id} done"    
  end
  

  dl_session(id)
  $child_count += 1    
end


puts "Waiting for all downloads to complete…"
Process.waitall
puts "Done."


