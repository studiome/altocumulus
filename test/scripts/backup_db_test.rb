require "test_helper"
require "tmpdir"
require "fileutils"

class BackupDbTest < ActiveSupport::TestCase
  setup do
    skip "sqlite3 CLI not available" unless system("command -v sqlite3 > /dev/null")
  end

  def create_source_db(path)
    system(
      "sqlite3", path,
      "CREATE TABLE t(id integer primary key, v text); INSERT INTO t(v) VALUES ('hello');",
      exception: true
    )
  end

  def run_backup(src:, dest:, keep: "30")
    system(
      { "BACKUP_SRC" => src, "BACKUP_DEST_DIR" => dest, "BACKUP_KEEP" => keep },
      Rails.root.join("bin/backup-db").to_s,
      out: File::NULL
    )
  end

  test "creates a compressed backup artifact" do
    Dir.mktmpdir do |dir|
      src = File.join(dir, "production.sqlite3")
      dest = File.join(dir, "backups")
      create_source_db(src)

      assert run_backup(src: src, dest: dest)

      artifacts = Dir.glob(File.join(dest, "production-*.sqlite3.gz"))
      assert_equal 1, artifacts.size
    end
  end

  test "backup can be restored and contains the original data" do
    Dir.mktmpdir do |dir|
      src = File.join(dir, "production.sqlite3")
      dest = File.join(dir, "backups")
      create_source_db(src)

      assert run_backup(src: src, dest: dest)

      artifact = Dir.glob(File.join(dest, "production-*.sqlite3.gz")).first
      assert artifact, "expected a backup artifact to exist"

      restored = artifact.delete_suffix(".gz")
      system("gunzip", "-k", artifact, exception: true)
      out = `sqlite3 #{restored} "SELECT v FROM t"`.strip
      assert_equal "hello", out
    end
  end

  test "prunes old backups to keep only the newest BACKUP_KEEP artifacts" do
    Dir.mktmpdir do |dir|
      src = File.join(dir, "production.sqlite3")
      dest = File.join(dir, "backups")
      create_source_db(src)
      FileUtils.mkdir_p(dest)

      old_paths = (1..5).map do |i|
        path = File.join(dest, "production-dummy#{i}.sqlite3.gz")
        File.write(path, "dummy")
        FileUtils.touch(path, mtime: Time.now - (i * 3600))
        path
      end

      assert run_backup(src: src, dest: dest, keep: "2")

      remaining = Dir.glob(File.join(dest, "production-*.sqlite3.gz*")).sort
      assert_equal 2, remaining.size

      newest_artifact = Dir.glob(File.join(dest, "production-*.sqlite3.gz*")) - old_paths
      assert_equal 1, newest_artifact.size, "expected the newly created backup to survive pruning"
      assert File.exist?(newest_artifact.first)
    end
  end
end
