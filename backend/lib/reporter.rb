module ArchivesSpace
  class Reporter
    attr_reader :data, :db

    GLOBAL_REPORT_RECORD_TABLES = [
      :accession, :agent_corporate_entity, :agent_family, :agent_person, :agent_software,
      :archival_object, :digital_object, :digital_object_component, :location, :repository,
      :resource, :subject, :top_container, :user
    ]

    REPO_REPORT_RECORD_TABLES = [
      :accession, :archival_object, :digital_object,
      :digital_object_component, :resource, :top_container
    ]

    def initialize(db:, sitecode:, name:, tier:, frontend_url:, public_url:)
      @data = {
        header: {
          sitecode: sitecode,
          name: name,
          tier: nil,
          frontend_url: frontend_url,
          public_url: public_url
        },
        report: {},
        checksum: nil
      }
      @db = db
    end

    def run
      @data[:header][:date] = Time.now
      @data[:report][:global] = gather_global_data
      @data[:report][:repository] = gather_repository_data
      @data[:checksum] = Digest::SHA2.hexdigest("#{@data[:header].to_s}#{@data[:report].to_s}")
      data
    end

    private

    def gather_global_data
      d = {}

      db.open do |dbc|
        GLOBAL_REPORT_RECORD_TABLES.each do |t|
          d[t] = dbc[t].count
        end

        # get the conditionable table stats
        d[:repository] = dbc[:repository].where(hidden: 0).count
        d[:user]       = dbc[:user].where(is_system_user: 0).count
        d[:total]      = d.values.inject(:+)

        # get last (any non-system) user login time for a sense of activity
        d[:user_last_mtime] = dbc[:user].
          where(is_system_user: 0).order(Sequel.desc(:user_mtime)).first[:user_mtime]
      end

      JSON.generate(d)
    end

    def gather_repository_data
      d = {}

      db.open do |dbc|
        dbc[:repository].where(hidden: 0).all.each do |r|
          d[r[:repo_code]]           = {}
          d[r[:repo_code]][:name]    = r[:name]
          d[r[:repo_code]][:publish] = r[:publish]

          REPO_REPORT_RECORD_TABLES.each do |t|
            d[r[:repo_code]][t] = dbc[t].where(repo_id: r[:id]).count
          end
        end
      end

      JSON.generate(d)
    end
  end
end
