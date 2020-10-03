# frozen_string_literal: true

$LOAD_PATH << File.expand_path("vendor/ruby/2.7.0/gems/gems-1.2.0/lib", __dir__)

require "logger"
require "json"
require "ostruct"
require "cgi"

class AlfredWorkflow
  attr_reader :query

  def initialize(query)
    @query = query
  end

  def feedback
    @feedback ||= {items: []}
  end

  def items
    feedback[:items]
  end

  def call
    debug ruby_version: RUBY_VERSION, query: query

    require "gems"

    gem_results = Gems.search(query)
    gem_results.each(&method(:build_gem_item))

    if gem_results.empty?
      items << {
        uid: "no-results",
        title: "No gems found for '#{query}'.",
        subtitle: "Search on rubygems.org instead",
        valid: true,
        icon: "#{__dir__}/icon.png",
        arg: "https://rubygems.org/search?query=#{CGI.escape(query)}"
      }
    end
  rescue StandardError => error
    error(error)
  ensure
    debug :feedback, feedback
    puts JSON.pretty_generate(feedback)
  end

  def build_gem_item(gem_data)
    gem_data = OpenStruct.new(gem_data)

    debug gem_data

    items << {
      uid: gem_data.name,
      title: gem_data.name,
      subtitle: "v#{gem_data.version} - #{gem_data.info}",
      arg: "https://rubygems.org/gems/#{gem_data.name}",
      icon: "#{__dir__}/icon.png",
      valid: true,
      mods: {
        alt: mod_item(title: "Source code url", arg: gem_data.source_code_uri),
        ctrl: mod_item(title: "Home page url", arg: gem_data.homepage_uri),
        cmd: mod_item(title: "Docs url", arg: gem_data.documentation_uri)
      }
    }
  end

  def mod_item(title:, arg:)
    valid = !arg.to_s.empty?

    {
      valid: valid,
      subtitle: valid ? "Open #{arg}" : "#{title} not available",
      arg: arg
    }
  end

  def logger
    @logger ||= Logger.new("/tmp/alfred.log")
  end

  def debug(*args, **kwargs)
    logger.debug(JSON.pretty_generate(args: args, kwargs: kwargs))
  end

  def error(error)
    logger.error(
      JSON.pretty_generate(
        class: error.class.name,
        message: error.message,
        backtrace: error.backtrace
      )
    )

    error_item = {
      uid: "error",
      subtitle: "Search on rubygems.org instead",
      arg: "https://rubygems.org/search?query=#{CGI.escape(query)}",
      valid: true
    }

    error_item[:title] = case error
                         when SocketError
                           "Couldn't fetch information from rubygems.org"
                         else
                           "Error: #{error.class}"
                         end

    items << error_item
  end
end

AlfredWorkflow.new(ARGV[0]).call
