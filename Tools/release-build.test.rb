require_relative "../fastlane/release_build"

def run(number, sha: "approved", tag: "v-release", workflow: ReleaseBuild::WORKFLOW)
  {"id" => number.to_s, "attributes" => {"number" => number, "sourceCommit" => {"commitSha" => sha}},
   "relationships" => {"workflow" => {"data" => {"id" => workflow}}}, "_tag" => tag}
end

def check(condition, message)
  raise message unless condition
end

check(ReleaseBuild.match([run(55), run(56, sha: "other")], "approved", "v-release")["id"] == "55", "Must not select another commit")
check(ReleaseBuild.match([run(55, tag: "v-other")], "approved", "v-release").nil?, "Must match the release tag")
check(ReleaseBuild.match([run(55, workflow: "development")], "approved", "v-release").nil?, "Must reject development builds")
check(ReleaseBuild.match([run(55), run(57)], "approved", "v-release")["id"] == "57", "Must choose the newest matching rerun")
check(ReleaseBuild.match([run(55).reject { |key, _| key == "_tag" }], "approved", "v-release").nil?, "Must reject an unknown source tag")
puts "5 release-build selection checks passed."
