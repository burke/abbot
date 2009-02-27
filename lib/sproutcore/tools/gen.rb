require File.join(SC::LIBPATH, 'sproutcore', 'helpers', 'generator_helper')

module SC
  
  # Generates components for SproutCore. The generator allows the user
  # to quickly set up a SproutCore framework using any of the built in templates
  # such as the project itself, apps, models, views, controllers and more
  # 
  # The template files will be copied to their target location and also be parsed
  # through the Erubis templating system. Template file paths can contain instance 
  # variables in the form of _class_name_ which in turn would be the value of 
  # @class_name once generated.
  # 
  # To develop a new generator, you can add it to the sproutcore/gen/ directory
  # with the following file structure:
  #    gen/
  #      <generator_name>/   - singular directory name of the generator
  #         Buildfile        - contains all configuration options and build tasks
  #         README           - prints when generator is done
  #         templates/       - contains all the files you want to generate
  #         USAGE            - prints when user gives sc-gen <generator_name> --help
  # 
  GENPATH = File.join(SC::LIBPATH, "..", "gen")
  
  class Tools
    include SC::GeneratorHelper
    
    def show_help(generator=nil, exists=NO)
      warn("There is no #{@generator} generator") if generator && !exists
      if generator && exists
        prints_content_of_file(generator, 'USAGE')
      else
        SC.logger << "Available generators:\n  #{generators.join("\n  ").gsub(/\//, '') }\n"
        SC.logger << "Type sc-gen generator --help for specific generator usage\n"
      end
    end
    
    desc "sc-gen generator Namespace[.ClassName] [--target=TARGET_NAME] [--filename=FILE_NAME]", 
      "Generates SproutCore components"
    
    method_options(
      MANIFEST_OPTIONS.merge(:help => :optional,
                             :filename => :optional,
                             :target => :optional))
      
    def gen(*arguments)
      return show_help if arguments.empty?
      
      # backwards compatibility case: client is a synonym for 'app'
      @generator = arguments[0]=='client' ? 'app' : arguments[0]
      generator_dir = File.join(SC::GENPATH, @generator, 'templates')
      
      return show_help(@generator, false) if !File.exists?(generator_dir)
      return show_help(@generator, true) if options[:help]
      
      # Buildfile inclusion
      #  -- NOTE: the generator system uses a custom configuration of 
      #  buildfiles and build rules that is separate from the regular build
      #  system.
      buildfile_location = File.join(SC::GENPATH, @generator, "Buildfile")
      info "Loading generator build file: " + buildfile_location
      
      @buildfile = SC::Buildfile.load(buildfile_location)
      @target_directory = @buildfile.config_for('/templates')[:root_dir]
      
      assign_names!(arguments[1])
      
      if options[:filename]
        # override the file_path with the passed in filename
        @file_path = options[:filename]
      end
      
      replace_with_instance_names!(@target_directory)
      append_to_class_name!
      append_to_file_path!
      
      debug "@namespace: " + @namespace.to_s
      debug "@class_name: " + @class_name.to_s
      debug "@namespace_with_class_name: " + @namespace_with_class_name.to_s
      debug "@method_name: " + @method_name.to_s
      debug "@class_nesting_depth: " + @class_nesting_depth.to_s
      debug "@file_path: " + @file_path.to_s
      debug "@mvc_type: " + @mvc_type.to_s
      debug "base_class_name(): " + base_class_name
      
      if options[:target] && @generator!='project'
        # prepend the target_directory with whatever is passed as --target
        @custom_target = YES
        @target_directory = options[:target]
      end
      
      begin
        # check all requirements in the Buildfile
        check_requirement_class_nesting_depth
        check_requirement_pwd
        check_requirement_root_dir
      rescue RuntimeError => error_message
        warn "For specific help on how to use this generator, type: sc-gen #{@generator} --help"
        fatal! error_message
      end
      
      info "target_directory: " + @target_directory
      
      # get list of template files to copy
      files = template_files(true, true, generator_dir, true)
      
      # copy files and parse them through Erubis in one swoop
      copy_files(files, @target_directory)

      prints_content_of_file(@generator, 'README')
      
    end
    
  end
end