class SeedDump
  module DumpMethods
    include Enumeration

    def dump(records, options = {})
      return nil if records.count == 0

      io = open_io(options)

      write_records_to_io(records, io, options)

      ensure
        io.close if io.present?
    end

    private

    def dump_record(record, options, record_attachment_strings = nil)
      attribute_strings = []

      # Also dump local ActiveStorage::Blob to a file
      if record.is_a?(ActiveStorage::Blob) && record.service_name == 'local'
        # export the blob to a file

        attachments_path = "#{File.dirname(retrieve_file_value(ENV))}/#{ENV['AS_ATTACHMENTS_FOLDER_NAME'] || 'attachments'}"

        # create attachments folder if it doesn't exist
        FileUtils.mkdir_p(attachments_path)

        File.open("#{attachments_path}/#{record.id}", "wb") do |f|
          f << record.download
        end

        if record_attachment_strings
          record_attachment_strings << "File.open(__dir__ + '/#{ENV['AS_ATTACHMENTS_FOLDER_NAME'] || 'attachments'}/#{record.id}') { |f| #{record.model_name.name}.find(#{record.id}).upload(f) }"
        end

        record
      end

      # We select only string attribute names to avoid conflict
      # with the composite_primary_keys gem (it returns composite
      # primary key attribute names as hashes).
      attributes_whitelist = attribute_names_for(record.class)

      record.attributes.select { |key| key.in?(attributes_whitelist) && (key.is_a?(String) || key.is_a?(Symbol)) }.each do |attribute, value|
        attribute_strings << dump_attribute_new(attribute, value, options) unless options[:exclude].include?(attribute.to_sym)
      end

      open_character, close_character = options[:import] ? ['[', ']'] : ['{', '}']

      "#{open_character}#{attribute_strings.join(", ")}#{close_character}"
    end

    def dump_attribute_new(attribute, value, options)
      options[:import] ? value_to_s(value) : "#{attribute}: #{value_to_s(value)}"
    end

    def value_to_s(value, recursive_call: false)
      should_inspect = true

      value = case value
              when BigDecimal, IPAddr
                value.to_s
              when Date, Time, DateTime
                # borrowed from https://github.com/rroblak/seed_dump/pull/161
                value.respond_to?(:to_fs) ? value.to_fs(:db) : value.to_s(:db)
              when Range
                range_to_string(value)
              # borrowed from PR https://github.com/rroblak/seed_dump/pull/73
              when ActiveSupport::HashWithIndifferentAccess
                return "#{value.to_s}.with_indifferent_access"
              when ->(v) { v.class.ancestors.map(&:to_s).include?('RGeo::Feature::Instance') }
                value.to_s
              when Array
                should_inspect = false

                value.map { |v|
                  value_to_s(v, recursive_call: true)
                }
              when ActionText::Content
                value.to_s # needs to be transferred as a string before the inspect will be called
              when Hash
                should_inspect = false

                Hash[value.map { |k, v|
                  [k, value_to_s(v, recursive_call: true)]
                }]

              when String
                should_inspect = !recursive_call
                value
              else
                if value.class.respond_to?(:attr_json_config)
                  should_inspect = false

                  # for serialized objects with attr_json gem, serialize the value correctly for later import
                  { 'type' => value.model_name.name }.merge(value_to_s(value.instance_variable_get(:@attributes), recursive_call: true))
                else
                  value
                end
              end

      should_inspect ? value.inspect : value
    end

    def range_to_string(object)
      from = object.begin.respond_to?(:infinite?) && object.begin.infinite? ? '' : object.begin
      to   = object.end.respond_to?(:infinite?) && object.end.infinite? ? '' : object.end
      "[#{from},#{to}#{object.exclude_end? ? ')' : ']'}"
    end

    def open_io(options)
      if options[:file].present?
        mode = options[:append] ? 'a+' : 'w+'

        File.open(options[:file], mode)
      else
        StringIO.new('', 'w+')
      end
    end

    def write_records_to_io(records, io, options)
      options[:exclude] ||= [:id, :created_at, :updated_at]

      # borrowed from PR https://github.com/rroblak/seed_dump/pull/140
      method = options[:import] ? 'import_without_validations_or_callbacks' : options[:import_method] # { create! (default) | insert_all! | upsert_all! }
      model_name = model_for(records)
      io.write("#{model_name}.#{method}(")
      if options[:import]
        io.write("[#{attribute_names(records, options).map {|name| name.to_sym.inspect}.join(', ')}], ")
      end
      io.write("[\n  ")

      enumeration_method = if records.is_a?(ActiveRecord::Relation) || records.is_a?(Class)
                             :active_record_enumeration
                           else
                             :enumerable_enumeration
                           end

      collected_attachment_strings = []

      send(enumeration_method, records, io, options) do |record_strings, last_batch, record_attachment_strings|
        io.write(record_strings.join(",\n  "))

        collected_attachment_strings += record_attachment_strings if record_attachment_strings&.any?

        io.write(",\n  ") unless last_batch
      end

      io.write("\n]#{active_record_import_options(options)})\n")

      if collected_attachment_strings&.any?
        io.write("\n#{collected_attachment_strings.join("\n")}\n\n")
      end

      # Increment the model's primary key sequence to the maximum value of the primary key column.
      if ActiveRecord::Base.connection.adapter_name == 'PostgreSQL' && options[:skip_sql_commands].blank?
        io.write("\nhighest_nr_array = ActiveRecord::Base.connection.execute(\"SELECT \#{#{model_name}.primary_key} FROM \#{#{model_name}.table_name} ORDER BY \#{#{model_name}.primary_key} DESC LIMIT 1\")")
        io.write("\nhighest_nr_array.any? && ActiveRecord::Base.connection.execute(\"ALTER SEQUENCE \#{#{model_name}.table_name}_id_seq  RESTART WITH \#{highest_nr_array.first.values.first + 1} \")\n\n")
      end

      if options[:file].present?
        nil
      else
        io.rewind
        io.read
      end
    end

    def active_record_import_options(options)
      return unless options[:import] && options[:import].is_a?(Hash)

      ', ' + options[:import].map { |key, value| "#{key}: #{value}" }.join(', ')
    end

    def attribute_names(records, options)
      attribute_names = if records.is_a?(ActiveRecord::Relation) || records.is_a?(Class)
                          attribute_names_for(records)
                        else
                          records[0].attribute_names
                        end

      attribute_names.select {|name| !options[:exclude].include?(name.to_sym)}
    end

    def attribute_names_for(base)
      base.attribute_types.map { |attr_name, type|
        case type.class.to_s
        when /^Active/, 'AttrJson::Type::ContainerAttribute'
          attr_name
        end
      }.compact
    end

    def model_for(records)
      if records.is_a?(Class)
        records
      elsif records.respond_to?(:model)
        records.model
      else
        records[0].class
      end
    end

  end
end
