module MediaPipeline
  class ArchiveContext

    attr_reader :rar_path, :archive_dir, :download_dir

    def initialize(rar_path, archive_dir, download_dir)
      @rar_path = rar_path
      @archive_dir = archive_dir
      @download_dir = download_dir
    end
  end
end