module ArchiveHelper

  def write_archive_parts(config, file, data_access)
    extract_path = "#{File.basename(File.dirname(file))}/#{File.basename(file)}"
    archive = MediaPipeline::RARArchive.new(config['local']['rar_path'], config['local']['archive_dir'], SecureRandom.uuid, extract_path)
    archive.add_file(file)
    parts = archive.archive
    data_access.write_archive(parts)
  end

  def save_archive(archive_key, config, file, data_access)
    keys = write_archive_parts(config, file, data_access)
    data_access.save_archive(archive_key, keys)
  end

end