class AWSPersister

  def initialize(opts={})
    required = [:ddb, :s3, :table_name, :bucket_name, :archive_prefix, :cover_art_prefix]
    missing = required.select { |key| opts[key].nil? }
    if not missing.empty?
      raise ArgumentError, "Missing options #{missing}"
    end
    @opts = opts
    @table = nil
  end

  def init_table
    @table = @opts[:ddb].tables[@opts[:table_name]]
    @table.hash_key = [:local_file_path, :string]
    @table.range_key = [:local_dir, :string]
  end

  def save_media_file(media_file)
    if @table.nil?
      init_table
    end
    tag_data = media_file.tag_data
    item = @table.items.create('local_file_path' =>File.absolute_path(media_file.file),
                               'local_dir' => File.dirname(File.absolute_path(media_file.file)))
    item.attributes.set(tag_data)
  end
end