require_relative 'lib/reporter'

unless AppConfig.has_key?(:aspace_reporter_debug)
  AppConfig[:aspace_reporter_debug] = false
end

unless AppConfig.has_key?(:aspace_reporter_schedule)
  AppConfig[:aspace_reporter_schedule] = "0 0 * * *"
end

unless AppConfig.has_key?(:aspace_reporter_secret_url)
  AppConfig[:aspace_reporter_secret_url] = nil
end

unless AppConfig.has_key?(:name)
  AppConfig[:name] = AppConfig[:cookie_prefix]
end

unless AppConfig.has_key?(:sitecode)
  AppConfig[:sitecode] = AppConfig[:cookie_prefix]
end

unless AppConfig.has_key?(:tier)
  AppConfig[:tier] = nil
end

ArchivesSpaceService.loaded_hook do
  ArchivesSpaceService.settings.scheduler.cron(
    AppConfig[:aspace_reporter_schedule],
    allow_overlapping: false, # TODO: [newer versions] overlap: false
    mutex: 'aspace.reporter',
    tags:  'aspace.reporter'
  ) do
    begin
      reporter = ArchivesSpace::Reporter.new(
        db: DB, # re-use our aspace db managed connection
        sitecode: AppConfig[:sitecode],
        name: AppConfig[:name],
        tier: AppConfig[:tier],
        frontend_url: AppConfig[:frontend_proxy_url],
        public_url: AppConfig[:public_proxy_url],
      )
      Log.info "Running reporter: #{Time.now}"
      reporter.run
      payload = { type: 'report', data: reporter.data }

      if AppConfig[:aspace_reporter_debug]
        Log.debug(payload)
        raise 'Exiting -- debug mode only [reporter]'
      end

      raise 'Messenger plugin not enabled [reporter]' unless AppConfig[:plugins].include? 'aspace-messenger'
      raise 'Reporter url is not defined [reporter]' unless AppConfig[:aspace_reporter_secret_url]

      Log.info "Sending report: #{Time.now}"
      messenger = ASpaceMessenger.new(
        enabled: true,
        payload: payload,
        url: AppConfig[:aspace_reporter_secret_url],
      )
      messenger.deliver
    rescue StandardError => e
      Log.error(e.message)
    end
  end
end
