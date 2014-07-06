module ArchiveHelper

  def write_archive_parts(config, file, data_access)
    extract_path = "#{File.basename(File.dirname(file))}"
    archive = MediaPipeline::RARArchive.new(config['local']['rar_path'], config['local']['archive_dir'], SecureRandom.uuid, extract_path)
    archive.add_file(file)
    parts = archive.archive
    data_access.write_archive(parts)
  end

  def save_archive(archive_key, config, file, data_access)
    keys = write_archive_parts(config, file, data_access)
    data_access.save_archive(archive_key, keys)
  end

  def cleanup_local_archives
    config = MediaPipeline::ConfigFile.new('./conf/config.yml', PIPELINES[ENV['ENVIRONMENT']]).config
    Dir.glob("#{config['local']['archive_dir']}/**/*.rar").each do | file |
      File.delete(file)
    end
  end

end