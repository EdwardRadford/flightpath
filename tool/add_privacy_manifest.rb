#!/usr/bin/env ruby
# Adds ios/Runner/PrivacyInfo.xcprivacy to the Runner target's Copy Bundle
# Resources build phase if it isn't already there. Idempotent — safe to run
# on every build, no-op if the reference already exists.
#
# Why: Apple requires the privacy manifest to be bundled inside the .app
# from May 2024. The file lives on disk at ios/Runner/PrivacyInfo.xcprivacy
# but isn't listed in Runner.xcodeproj. Ed builds via Codemagic only and
# never opens Xcode, so the standard "drag into Xcode" fix isn't workable.
# This script patches the pbxproj programmatically.
#
# Usage: run from repo root (Codemagic does this).
#   ruby tool/add_privacy_manifest.rb
#
# Requires: the `xcodeproj` gem. Tested with xcodeproj 1.25.x (the version
# bundled with recent fastlane, which is preinstalled on Codemagic mac_mini
# images). Any 1.x release should work — the API surface used here
# (Project.open, target.resources_build_phase, group.new_reference,
# recursive_children) has been stable since 1.0.

require 'xcodeproj'

project_path = File.join(__dir__, '..', 'ios', 'Runner.xcodeproj')
manifest_path_in_runner = 'PrivacyInfo.xcprivacy'  # relative to ios/Runner

# Sanity check the manifest exists on disk. If we add a reference to a
# missing file, Xcode shows a red filename and the build silently omits it.
manifest_disk_path = File.join(__dir__, '..', 'ios', 'Runner', manifest_path_in_runner)
abort "PrivacyInfo.xcprivacy not found at #{manifest_disk_path}" unless File.exist?(manifest_disk_path)

project = Xcodeproj::Project.open(project_path)
runner_target = project.targets.find { |t| t.name == 'Runner' }
abort 'Runner target not found' unless runner_target

runner_group = project.main_group['Runner']
abort 'Runner group not found' unless runner_group

# Look for an existing reference to the manifest, anywhere under the Runner
# group, to avoid double-adding.
existing_ref = runner_group.recursive_children.find do |c|
  c.is_a?(Xcodeproj::Project::Object::PBXFileReference) &&
    c.path == manifest_path_in_runner
end

if existing_ref.nil?
  existing_ref = runner_group.new_reference(manifest_path_in_runner)
  puts "Added file reference for #{manifest_path_in_runner}"
else
  puts "File reference already present for #{manifest_path_in_runner}"
end

resources_phase = runner_target.resources_build_phase
already_in_phase = resources_phase.files.any? do |bf|
  bf.file_ref == existing_ref
end

if already_in_phase
  puts 'PrivacyInfo.xcprivacy already in Copy Bundle Resources — nothing to do'
  # Still call save() below so file-reference-only adds get persisted; if
  # both checks were no-ops, save() writes an unchanged project (cheap).
else
  resources_phase.add_file_reference(existing_ref)
  puts 'Added PrivacyInfo.xcprivacy to Copy Bundle Resources'
end

project.save
puts "Saved #{project_path}"
