#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "optparse"
require "time"

MANAGED_PROMPTS = [
  ["handy_config_cleanup", "Clean Up Transcription", "prompt.md"],
  ["handy_config_translate_to_english", "Translate to English", "translate-to-english.md"],
  ["handy_config_translate_to_x", "Translate to X", "translate-to-x.md"]
].freeze

options = {
  settings: File.join(Dir.home, "Library", "Application Support", "com.pais.handy", "settings_store.json")
}

OptionParser.new do |parser|
  parser.banner = "Usage: sync_handy_prompts.rb --repo PATH [--settings PATH]"
  parser.on("--repo PATH", "Path to the handy-config repository") { |value| options[:repo] = value }
  parser.on("--settings PATH", "Path to Handy's settings_store.json") { |value| options[:settings] = value }
end.parse!

abort "Missing required option: --repo PATH" unless options[:repo]

repo_path = File.expand_path(options[:repo])
settings_path = File.expand_path(options[:settings])
default_settings_path = File.join(Dir.home, "Library", "Application Support", "com.pais.handy", "settings_store.json")

unless File.file?(settings_path)
  abort "Handy settings file not found: #{settings_path}"
end

if settings_path == default_settings_path && system("pgrep", "-x", "handy", out: File::NULL, err: File::NULL)
  abort "Handy is running. Close it before syncing so it cannot overwrite the update."
end

managed = MANAGED_PROMPTS.map do |id, name, filename|
  source_path = File.join(repo_path, filename)
  abort "Prompt file not found: #{source_path}" unless File.file?(source_path)

  prompt = File.read(source_path, mode: "r:BOM|UTF-8")
  count = prompt.scan(/\$\{output\}/).length
  abort "Expected exactly one literal ${output} placeholder in #{source_path}; found #{count}" unless count == 1

  { "id" => id, "name" => name, "prompt" => prompt }
end

begin
  document = JSON.parse(File.read(settings_path, mode: "r:BOM|UTF-8"))
rescue JSON::ParserError => e
  abort "Handy settings are not valid JSON: #{e.message}"
end

settings = document["settings"]
abort "Unsupported Handy settings schema: missing object at .settings" unless settings.is_a?(Hash)

existing = settings["post_process_prompts"]
abort "Unsupported Handy settings schema: .settings.post_process_prompts is not an array" unless existing.is_a?(Array)

managed_ids = managed.map { |prompt| prompt["id"] }
previous_selection = settings["post_process_selected_prompt_id"]
settings["post_process_prompts"] = existing.reject { |prompt| managed_ids.include?(prompt["id"]) } + managed
settings["post_process_selected_prompt_id"] = MANAGED_PROMPTS.first.first if previous_selection.nil? || previous_selection.empty?

timestamp = Time.now.strftime("%Y%m%d-%H%M%S")
backup_path = "#{settings_path}.backup-#{timestamp}"
suffix = 1
while File.exist?(backup_path)
  backup_path = "#{settings_path}.backup-#{timestamp}-#{suffix}"
  suffix += 1
end

File.open(backup_path, "wb", File.stat(settings_path).mode & 0o777) do |backup|
  backup.write(File.binread(settings_path))
end

temporary_path = "#{settings_path}.tmp-handy-prompt-sync-#{Process.pid}"
begin
  File.open(temporary_path, "wb", File.stat(settings_path).mode & 0o777) do |temporary|
    temporary.write(JSON.pretty_generate(document))
    temporary.write("\n")
    temporary.flush
    temporary.fsync
  end
  File.rename(temporary_path, settings_path)
ensure
  File.delete(temporary_path) if File.exist?(temporary_path)
end

written = JSON.parse(File.read(settings_path, mode: "r:BOM|UTF-8"))
written_prompts = written.fetch("settings").fetch("post_process_prompts")
managed.each do |expected|
  actual = written_prompts.find { |prompt| prompt["id"] == expected["id"] }
  abort "Verification failed for #{expected["name"]}" unless actual == expected
end

selection = written.fetch("settings")["post_process_selected_prompt_id"]
selection_status = previous_selection == selection ? "preserved" : "set to #{selection}"

puts "Synced #{managed.length} Handy prompts from #{repo_path}"
puts "Selection: #{selection_status}"
puts "Backup: #{backup_path}"
