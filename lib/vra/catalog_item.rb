# frozen_string_literal: true
#
# Author:: Chef Partner Engineering (<partnereng@chef.io>)
# Copyright:: Copyright (c) 2015 Chef Software, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require "ffi_yajl" unless defined?(FFI_Yajl)
require "vra/catalog"

module Vra
  # Class that represents the Catalog Item
  class CatalogItem < Vra::CatalogBase
    INDEX_URL = '/catalog/api/admin/items'

    attr_reader :id, :client

    def initialize(client, opts)
      super
      validate!

      if @data.nil?
        fetch_catalog_item
      else
        @id = @data['id']
      end
    end

    def fetch_catalog_item
      @data = client.get_parsed("/catalog/api/admin/items/#{id}")
    rescue Vra::Exception::HTTPNotFound
      raise Vra::Exception::NotFound, "catalog ID #{id} does not exist"
    end

    def name
      @data['name']
    end

    def description
      @data['description']
    end

    def source_id
      @data['sourceId']
    end

    def source_name
      @data['sourceName']
    end

    def source
      @source ||= Vra::CatalogSource.new(client, id: source_id)
    end

    def type
      @type ||= Vra::CatalogType.new(client, data: @data[:type])
    end

    def icon_id
      @data['iconId']
    end

    def status
      @data['status']
    end

    def organization
      return {} if @data['organization'].nil?

      @data['organization']
    end

    def tenant_id
      organization['tenantRef']
    end

    def tenant_name
      organization['tenantLabel']
    end

    def subtenant_id
      organization['subtenantRef']
    end

    def subtenant_name
      organization['subtenantLabel']
    end

    def blueprint_id
      @data['providerBinding']['bindingId']
    end

    def entitle!(opts = {})
      super(opts.merge(type: 'CatalogItemIdentifier'))
    end

    # @param [String] - the id of the catalog item
    # @param [Vra::Client] - a vra client object
    # @return [String] - returns a json string of the catalog template
    def self.dump_template(client, id)
      response = client.http_get("/catalog-service/api/consumer/entitledCatalogItems/#{id}/requests/template")
      response.body
    end

    # @param client [Vra::Client] - a vra client object
    # @param id [String] - the id of the catalog item
    # @param filename [String] - the name of the file you want to output the template to
    # if left blank, will default to the id of the item
    # @note outputs the catalog template to a file in serialized format
    def self.write_template(client, id, filename = nil)
      filename ||= "#{id}.json"
      begin
        contents = dump_template(client, id)
        data = JSON.parse(contents)
        pretty_contents = JSON.pretty_generate(data)
        File.write(filename, pretty_contents)
        filename
      rescue Vra::Exception::HTTPError => e
        raise e
      end
    end

    # @param [Vra::Client] - a vra client object
    # @param [String] - the directory path to write the files to
    # @param [Boolean] - set to true if you wish the file name to be the id of the catalog item
    # @return [Array[String]] - a array of all the files that were generated
    def self.dump_templates(client, dir_name = "vra_templates", use_id = false)
      FileUtils.mkdir_p(dir_name) unless File.exist?(dir_name)
      client.catalog.entitled_items.map do |c|
        id = use_id ? c.id : c.name.tr(" ", "_")
        filename = File.join(dir_name, "#{id}.json").downcase
        write_template(client, c.id, filename)
        filename
      end
    end
  end
end
