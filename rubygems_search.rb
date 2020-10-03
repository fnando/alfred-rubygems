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

    mods = {}

    if gem_data.source_code_uri
      mods[:alt] = {
        arg: gem_data.source_code_uri,
        subtitle: "Open #{gem_data.source_code_uri}"
      }
    end

    if gem_data.homepage_uri
      mods[:ctrl] = {
        arg: gem_data.homepage_uri,
        subtitle: "Open #{gem_data.homepage_uri}"
      }
    end

    if gem_data.documentation_uri
      mods[:cmd] = {
        arg: gem_data.documentation_uri,
        subtitle: "Open #{gem_data.documentation_uri}"
      }
    end

    items << {
      uid: gem_data.name,
      title: gem_data.name,
      subtitle: "v#{gem_data.version} - #{gem_data.info}",
      arg: "https://rubygems.org/gems/#{gem_data.name}",
      icon: "#{__dir__}/icon.png",
      valid: true,
      mods: mods
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

    items << case error
             when SocketError
               {
                 uid: "error",
                 title: "Couldn't fetch information from rubygems.org",
                 subtitle: "Search on rubygems.org instead",
                 arg: "https://rubygems.org/search?query=#{CGI.escape(query)}",
                 valid: true
               }
             else
               {
                 title: "Error: #{error.class}",
                 subtitle: "Search on rubygems.org instead",
                 arg: "https://rubygems.org/search?query=#{CGI.escape(query)}",
                 valid: true
               }
             end
  end
end

AlfredWorkflow.new(ARGV[0]).call
