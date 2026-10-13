# Identify the release build by its Xcode Cloud workflow, commit, and tag.
module ReleaseBuild
  PRODUCT = "603F5035-E1D3-4525-A3C0-8276542E30CA"
  WORKFLOW = "A72AD319-61AE-4768-91C6-B2F0745FCCA3"

  def self.match(runs, sha, tag)
    runs.select do |run|
      attributes = run.fetch("attributes")
      relationships = run.fetch("relationships")
      attributes.dig("sourceCommit", "commitSha") == sha &&
        relationships.dig("workflow", "data", "id").to_s.downcase == WORKFLOW.downcase &&
        run["_tag"] == tag
    end.max_by { |run| run.fetch("attributes").fetch("number") }
  end

  def self.wait(client, sha:, tag:, version:, timeout: 1800)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    loop do
      runs = client.get("v1/ciProducts/#{PRODUCT}/buildRuns", {limit: 100, sort: "-number", include: "sourceBranchOrTag,workflow"}).body
      refs = (runs["included"] || []).to_h { |ref| [ref["id"], ref.dig("attributes", "name")] }
      data = runs.fetch("data").map { |run| run.merge("_tag" => refs[run.dig("relationships", "sourceBranchOrTag", "data", "id")]) }
      run = match(data, sha, tag)
      if run
        status = run.dig("attributes", "completionStatus")
        raise "Release archive failed: #{status}" if %w[FAILED ERRORED CANCELED SKIPPED].include?(status)
        if status == "SUCCEEDED"
          builds = client.get("v1/ciBuildRuns/#{run.fetch('id')}/builds").body.fetch("data")
          ready = builds.find { |build| build.dig("attributes", "processingState") == "VALID" }
          if ready
            train = client.get("v1/builds/#{ready.fetch('id')}/preReleaseVersion").body.fetch("data")
            raise "Release build version mismatch" unless train.dig("attributes", "version") == version
            return ready.fetch("attributes").fetch("version")
          end
          raise "Release upload was rejected" if builds.any? { |build| %w[INVALID FAILED].include?(build.dig("attributes", "processingState")) }
        end
      end
      raise "Timed out waiting for the release commit's processed build" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
      puts "Waiting for release #{tag} to finish processing…"
      sleep 30
    end
  end
end
