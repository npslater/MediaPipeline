require 'optparse'
require 'aws-sdk'
require 'Taglib'

def parse(args)

    options = {}
    parser = OptionParser.new do |opts|
        opts.banner = "Usage: index_files.rb [options]"
        opts.separator ""
        opts.separator "Specific options:"
        opts.on('-d', '--dir DIR',
                'The directory to index') do | dir |
            options[:dir] = dir
        end

        opts.on('-e', '--ext EXTENSION', 'The extension of files to index') do | ext |
            options[:ext] = ext
        end
    end
    parser.parse!(args)
    mandatory = [:dir, :ext]
    missing = mandatory.select{|param| options[param].nil?}
    if not missing.empty?
        puts "Missing options: #{missing.join(', ')}"
        puts parser
        exit
    end
    options
end

def read_tag(file)
    info = nil
    TagLib::FileRef.open(file) do |fileref|
        unless fileref.null?
            tag = fileref.tag
            info = {
                :title => tag.title,   
                :artist => tag.artist,  
                :album => tag.album,   
                :year => tag.year,    
                :track => tag.track,   
                :genre => tag.genre,   
                :comment => tag.comment 
            }
        end
    end
    TagLib::MP4::File.open(file) do |mp4|
        frame = mp4.tag.item_list_map['disk']
        unless frame.nil?
            puts frame.to_int
        end
        item_list_map = mp4.tag.item_list_map.to_a.each do | frame |
            #puts "#{frame[0]}--#{frame[1]}"
        end
    end
    info
end

options = parse(ARGV)
Dir.glob("#{options[:dir]}/**/*.#{options[:ext]}").each do | file |
    item = read_tag(file)
    #puts item
end


