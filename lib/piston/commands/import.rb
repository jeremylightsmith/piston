require "piston/commands/base"

module Piston
  module Commands
    class Import < Piston::Commands::Base
      attr_reader :options

      def temp_dir_name(working_copy)
        working_copy.path.parent + ".#{working_copy.path.basename}.tmp"
      end
      
      def repository_type
        options[:repository_type]
      end
      
      def select_repository(repository_url)
        if repository_type then
          logger.info {"Forced repository type to #{repository_type}"}
          repository_class_name = "Piston::#{repository_type.downcase.capitalize}::Repository"
          repository_class = constantize(repository_class_name)
          repository_class.new(repository_url)
        else
          logger.info {"Guessing the repository type"}
          Piston::Repository.guess(repository_url)
        end
      end

      def run(repository_url, target_revision, wcdir)
        repository = select_repository(repository_url)
        revision = repository.at(target_revision)

        wcdir = wcdir.nil? ? repository.basename : wcdir
        logger.info {"Guessing the working copy type"}
        logger.debug {"repository_url: #{repository_url.inspect}, target_revision: #{target_revision.inspect}, wcdir: #{wcdir.inspect}"}
        working_copy = guess_wc(wcdir)

        tmpdir = temp_dir_name(working_copy)

        if working_copy.exist? && !force then
          logger.fatal "Path #{working_copy} already exists and --force not given.  Aborting..."
          abort
        end

        begin
          logger.info {"Checking out the repository"}
          revision.checkout_to(tmpdir)

          logger.debug {"Creating the local working copy"}
          working_copy.create

          logger.info {"Copying from #{revision}"}
          working_copy.copy_from(revision)

          logger.debug {"Remembering values"}
          working_copy.remember({:repository_url => repository.url, :lock => options[:lock], :repository_class => repository.class.name},
                                revision.remember_values)

          logger.debug {"Finalizing working copy"}
          working_copy.finalize

          logger.info {"Checked out #{repository_url.inspect} #{revision.name} to #{wcdir.inspect}"}
        ensure
          logger.debug {"Removing temporary directory: #{tmpdir}"}
          tmpdir.rmtree rescue nil
        end
      end
    end
  end
end
