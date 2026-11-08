require "net/http"

# Uploads to the backup bucket through Cloud Storage's JSON API, as the VM's service account.
# The token comes from the metadata server, as it does for Litestream, so there's no key file.
class CloudStorage
  class Error < StandardError; end

  METADATA_TOKEN_URL = URI("http://169.254.169.254/computeMetadata/v1/instance/service-accounts/default/token")

  def initialize(bucket = ENV.fetch("BACKUP_BUCKET"))
    @bucket = bucket
  end

  def upload(path, name, content_type: "application/octet-stream")
    uri = URI("https://storage.googleapis.com/upload/storage/v1/b/#{@bucket}/o")
    uri.query = URI.encode_www_form(uploadType: "media", name: name)
    request = Net::HTTP::Post.new(uri, "Authorization" => "Bearer #{token}", "Content-Type" => content_type)
    request.body = File.binread(path)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
    raise Error, "upload of #{name} failed: #{response.code} #{response.body.to_s[0, 300]}" unless response.is_a?(Net::HTTPSuccess)

    "gs://#{@bucket}/#{name}"
  end

  private

  def token
    response = Net::HTTP.get_response(METADATA_TOKEN_URL, "Metadata-Flavor" => "Google")
    raise Error, "no token from the metadata server: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body).fetch("access_token")
  end
end
