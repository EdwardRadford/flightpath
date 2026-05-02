#!/usr/bin/env ruby
# Adds ios/Runner/PrivacyInfo.xcprivacy to the Runner target's Copy Bundle
# Resources build phase if it isn't already there. Idempotent — safe to run
# on every build.
#
# Required by Apple App Store from May 2024. Without this, the manifest sits
# next to the build but isn't bundled into the .app, so reviewers see a
# missing-manifest warning.
#
# Run from repo root via Codemagic. Requires the `xcodeproj` gem
# (`gem install xcodeproj` in the workflow before invoking this).

require 'xcodeproj'

project_path = File.join(__dir__, '..', 'ios', 'Runner.xcodeproj')
manifest_path_in_runner = 'PrivacyInfo.xcprivacy'  # relative to ios/Runner

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
else
  resources_phase.add_file_reference(existing_ref)
  puts 'Added PrivacyInfo.xcprivacy to Copy Bundle Resources'
end

project.save
puts "Saved #{project_path}"
