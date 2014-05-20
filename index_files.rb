require 'optparse'
require 'aws-sdk'

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

options = parse(ARGV)
Dir.glob("#{options[:dir]}/**/*.#{options[:ext]}").each do | file |
    puts file
end


