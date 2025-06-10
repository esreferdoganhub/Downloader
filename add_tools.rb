#!/usr/bin/env ruby
require 'xcodeproj'

# Proje dosyası ve target adını kendi projenize göre ayarlayın:
project = Xcodeproj::Project.open('downloader.xcodeproj')
target  = project.targets.find { |t| t.name == 'downloader' }

# Ana grupta Tools klasörünü (folder reference) oluştur
tools_group = project.main_group.find_subpath('Tools', true)
tools_group.set_source_tree('SOURCE_ROOT')

# Eklemek istediğiniz ikililer
%w[yt-dlp ffmpeg aria2c].each do |tool|
  file_ref = tools_group.new_file("Tools/\#{tool}")
  target.resources_build_phase.add_file_reference(file_ref)
end

project.save
