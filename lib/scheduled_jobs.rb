# Functions to run on a periodic basis
module ScheduledJobs
  class << self
    def job_files
      files = Dir[Rails.root.join('config', 'cronic.d', '*.rb')]
      GalleryConfig.directories.extensions.each do |dir|
        files += Dir[File.join(dir, '*', 'cronic.d', '*.rb')]
      end
      files
    end

    def log(message)
      message = "#{Time.current}: #{message}"
      Rails.logger.info(message)
      # Print to stdout so it goes to cronic.log too
      # rubocop: disable Rails/Output
      puts message if defined?(Cronic::Scheduler) || !GalleryConfig.scheduler.internal
      # rubocop: enable Rails/Output
    end

    def run(name)
      if Rails.env.development? && ENV['NOJOBS']
        log("SCHEDULER: jobs disabled; skipping #{name}")
        return
      end
      log("SCHEDULER: running #{name}")
      start = Time.current
      send(name)
      time = Time.current - start
      log("SCHEDULER: #{name} complete (#{time.to_i}s)")
    rescue StandardError => ex
      log("SCHEDULER: error running #{name}: #{ex.class}: #{ex.message}")
    end

    def hello
      log('Hello, world!')
    end

    def similarity_scores
      # These are used for notebook suggestions.
      start = Time.current
      status = NotebookSimilarity.compute_all
      log("COMPUTE: notebook similarity #{Time.current - start}")
      log("COMPUTE:   -- #{status}")

      start = Time.current
      status = UsersAlsoView.matrix_compute
      log("COMPUTE: users also viewed matrix #{Time.current - start}")
      log("COMPUTE:   -- #{status}")

      start = Time.current
      status = UserSimilarity.matrix_compute
      log("COMPUTE: user similarity matrix #{Time.current - start}")
      log("COMPUTE:   -- #{status}")
    end

    def recommendations
      # Notebook recommendations first -
      # they're used as input for tag/group recommendations.
      start = Time.current
      status = SuggestedNotebook.compute_all
      log("COMPUTE: notebook recommendations #{Time.current - start}")
      log("COMPUTE:   -- #{status}")

      start = Time.current
      SuggestedGroup.compute_all
      log("COMPUTE: group recommendations #{Time.current - start}")

      start = Time.current
      SuggestedTag.compute_all
      log("COMPUTE: tag recommendations #{Time.current - start}")
    end

    def wordclouds
      start = Time.current
      Keyword.compute_all
      log("COMPUTE: top keywords #{Time.current - start}")

      start = Time.current
      Tag.generate_wordcloud
      log("COMPUTE: tag cloud #{Time.current - start}")

      start = Time.current
      Keyword.generate_wordcloud
      log("COMPUTE: keyword cloud #{Time.current - start}")

      start = Time.current
      Notebook.generate_all_wordclouds
      log("COMPUTE: notebook clouds #{Time.current - start}")
    end

    def reviews
      start = Time.current
      Review.generate_queue
      log("COMPUTE: review queue #{Time.current - start}")

      start = Time.current
      RecommendedReviewer.recommend_technical_reviewers
      log("COMPUTE: technical reviewers #{Time.current - start}")

      start = Time.current
      RecommendedReviewer.recommend_functional_reviewers
      log("COMPUTE: functional reviewers #{Time.current - start}")

      start = Time.current
      RecommendedReviewer.recommend_compliance_reviewers
      log("COMPUTE: compliance reviewers #{Time.current - start}")
    end

    def nightly_computation
      log('COMPUTE: beginning nightly computation')
      similarity_scores
      recommendations
      reviews
      wordclouds
      log('COMPUTE: finished nightly computation')
    end

    def notebook_dailies
      NotebookDaily.age_off
      NotebookDaily.compute_all
    end

    def age_off
      Stage.age_off
      ChangeRequest.age_off
    end

    def notebook_summaries
      NotebookSummary.compute_all
    end

    def user_summaries
      UserSummary.generate_all
    end
  end
end
