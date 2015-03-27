require 'securerandom'
require 'rubygems'

require_relative 'file_manager'
require_relative 'Components/PBXClasses/pbx_class'
require_relative  'Components/BuildSettings/build_settings'
require_relative 'PropertyFile/property_reader'

module AppContainer
class PBXProjectManager

  attr_reader :pathname
  attr_reader :file
  attr_reader :archiveVersion
  attr_reader :classes
  attr_reader :objectVersion

  attr_accessor :PBXProjectSection
  attr_accessor :PBXBuildFiles
  attr_accessor :PBXFileReferences
  attr_accessor :PBXSourcesBuildPhases
  attr_accessor :XCBuildConfigurations
  attr_accessor :XCConfigurationLists

  attr_accessor :targets
  attr_accessor :otherObjects
  attr_accessor :root_object
  attr_accessor :groups
  attr_accessor :assetcatalogs

  attr_accessor :objects
  attr_accessor :rootObject
  attr_accessor :allObjects

  attr_accessor :projectUUID

  def initialize(path)
    @pathname = path
  end

  def fetch
    convertToJSON
    @file = AppContainer::FileManager.OpenRead(@json_pathname)
    @content = @file.read
    hash = JSON[@content]
    @rootObject = hash['rootObject']
    @objects = hash['objects']
    @objectVersion = hash['objectVersion']
    @classes = hash['classes']
    @archiveVersion = hash['archiveVersion']
    @allObjects = hash
    initInstanceVariable
    @file.close
    fetchAllPBXObject

  end

  def initInstanceVariable
    @PBXBuildFiles = Hash.new
    @PBXFileReferences  = Hash.new
    @PBXSourcesBuildPhases = Hash.new
    @XCBuildConfigurations = Hash.new
    @XCConfigurationLists = Hash.new
    @groups = Hash.new
    @targets = Hash.new
    @otherObjects = Hash.new
    @assetcatalogs = Array.new
  end

  def convertToJSON
    output_file = File.join(AppContainer::PropertyReader.Properties['TEMP_FOLDER'],'temp_pbx_project.json')
    command = 'plutil -convert json -r -o '+output_file+' -- '+@pathname.to_s
    output_obj = AppContainer::FileManager.PerformCommand(command)
    raise "AppContainer::project.pbxproj is not  converted toJSON successfully" unless  AppContainer::FileManager.fileExits?(output_file)
    @json_pathname = File.new(Pathname.new(output_file))
  end

  def fetchAllPBXObject

    @objects.each do |key,value|
      case value['isa']
        when "PBXBuildFile"
          @PBXBuildFiles[key] = AppContainer::PBXBuildFile.new(value)

        when "PBXProject"
          @PBXProjectSection = AppContainer::PBXProject.new(value)
          @projectUUID = key
        when "PBXGroup"
          @groups[key] = AppContainer::PBXGroup.new(value)
        when "PBXFileReference"
          @PBXFileReferences[key] = AppContainer::PBXFileReference.new(value)
          if (@PBXFileReferences[key].lastKnownFileType == $FILE_TYPES_BY_EXTENSION['xcassets'])
            @assetcatalogs << @PBXFileReferences[key]
          end

        when "PBXResourcesBuildPhase"
        when "PBXFrameworksBuildPhase"
        when "PBXSourcesBuildPhase"
        when "PBXNativeTarget"
          @targets[key] = AppContainer::BuildPhases.new(key,value)

        when "XCBuildConfiguration"
          @XCBuildConfigurations[key] = AppContainer::XCBuildConfiguration.new(value)
          @XCBuildConfigurations[key].prepare_method
        when "XCConfigurationList"
          @XCConfigurationLists[key] = AppContainer::XCConfigurationList.new(value)

        when nil
          raise "PBXObject is not Vaild #{key}:#{value}"
        else
          @otherObjects[key] = value
      end
    end

    prepareTargets

  end

  def prepareTargets

    @targets.each do |key,target|

      target.root.buildPhases.each do |uuid|
        case @objects[uuid]['isa']
          when "PBXSourcesBuildPhase"
            target.addSourcesBuildPhases(uuid,@objects[uuid])
          when "PBXFrameworksBuildPhase"
            target.addFrameworkBuildPhases(uuid,@objects[uuid])
          when "PBXResourcesBuildPhase"
            target.addResourcesBuildPhases(uuid,@objects[uuid])
        end

      end
    end

  end

  def updateAllPBXObject # To Do optimize
    @objects.clear
    @objects.merge!({@projectUUID => @PBXProjectSection.generateHash})
    @objects.merge!(@PBXBuildFiles.reduce({}){ |hash, (k, v)| hash.merge( k => v.generateHash )  })
    @objects.merge!(@targets.reduce({}){ |hash, (k,v)| hash.merge(v.generateHash ) })
    @objects.merge!(@PBXFileReferences.reduce({}){ |hash, (k, v)| hash.merge( k => v.generateHash )  })
    @objects.merge!(@groups.reduce({}){ |hash, (k, v)| hash.merge( k => v.generateHash )  })
    @objects.merge!(@XCBuildConfigurations.reduce({}){ |hash, (k,v)| hash.merge(k => v.generateHash ) })
    @objects.merge!(@XCConfigurationLists.reduce({}){ |hash, (k, v)| hash.merge( k => v.generateHash )  })
    @objects.merge!(@otherObjects)
    setAllPBXObjects
  end

  def setAllPBXObjects
    @allObjects = Hash.new
    @allObjects['rootObject'] = @rootObject
    @allObjects['objects'] = @objects
    @allObjects['objectVersion'] = @objectVersion
    @allObjects['classes'] = @classes
    @allObjects['archiveVersion'] = @archiveVersion
  end

  # def createPBXPROJ(archiveVersion:1,objectVersion:46,project)
  #   uuid = SecureRandom.uuid.to_s
  #   @rootObject = uuid.split("-")[1..-1].join().upcase
  #   @objects[uuid] =  project
  #   @objects[project.mainGroup] = AppContainer::PBXGroup.new
  #   @objects[project.buildConfigurationList] = AppContainer::XCConfigurationList.new
  #   setAllPBXObjects
  # end
end
end