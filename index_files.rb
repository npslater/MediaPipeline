require 'optparse'
require 'aws-sdk'
require 'Taglib'
require 'yaml'

def parse(args)

    options = {}
    parser = OptionParser.new do |opts|
        opts.banner = "Usage: index_files.rb [options]"
        opts.separator ""
        opts.separator "Specific options:"
        opts.on('-c', '--config CONFIG', 'The path to the config file') do | config |
            options[:config] = config
        end
        opts.on('-d', '--dir DIR',
                'The directory to index') do | dir |
            options[:dir] = dir
        end

        opts.on('-e', '--ext EXTENSION', 'The extension of files to index') do | ext |
            options[:ext] = ext
        end
    end
    parser.parse!(args)
    mandatory = [:dir, :ext, :config]
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
            info[:disk] = frame.to_int
        end
        cover_art_list = mp4.tag.item_list_map['covr'].to_cover_art_list
        cover_art = cover_art_list.first
        info[:cover_art] = cover_art.data
    end
    info
end

options = parse(ARGV)
config = YAML.load(File.read(options[:config]))
Dir.glob("#{options[:dir]}/**/*.#{options[:ext]}").each do | file |
    info = read_tag(file)
    puts info
end


