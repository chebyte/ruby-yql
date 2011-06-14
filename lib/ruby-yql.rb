require 'net/http'
require 'hpricot'
require 'cgi'
require 'uri'
require 'cgi'
require 'openssl'
require 'base64'

module Chebyte
  class OauthUtil

    attr_accessor :consumer_key, :consumer_secret, :token, :token_secret, :req_method, :sig_method, :oauth_version, :callback_url, :params

    def initialize
      @consumer_key = ''
      @consumer_secret = ''
      @token = ''
      @token_secret = ''
      @req_method = 'GET'
      @sig_method = 'HMAC-SHA1'
      @oauth_version = '1.0'
      @callback_url = ''
      @params = []
    end

    def generate_nonce
      Array.new( 5 ) { rand(256) }.pack('C*').unpack('H*').first
    end

    def percent_encode( string )
      URI.escape( string, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]") )
    end

    def normalize_req_params( params )
      percent_encode( params.sort().join( '&' ) )
    end

    def construct_req_url( url)
      parsed_url = URI.parse( url )
      parsed_url.scheme + '://' + parsed_url.host + parsed_url.path
    end

    def generate_sig( args )
      key     = percent_encode( args[:consumer_secret] ) + '&' + percent_encode( args[:token_secret] )
      text    = args[:base_str]
      digest  = OpenSSL::Digest::Digest.new( 'sha1' )
      raw_sig = OpenSSL::HMAC.digest( digest, key, text )
      Base64.encode64( raw_sig ).chomp.gsub( /\n/, '' )
    end

    def to_query_string
      @params.join('&')
    end

    def sign( url )

      parsed_url = URI.parse( url )

      @params.push( 'oauth_consumer_key=' + @consumer_key )
      @params.push( 'oauth_nonce=' + generate_nonce() )
      @params.push( 'oauth_signature_method=' + @sig_method )
      @params.push( 'oauth_timestamp=' + Time.now.to_i.to_s )
      @params.push( 'oauth_version=' + @oauth_version )

      if parsed_url.query
        @params = @params | parsed_url.query.split( '&' )
      end

      normal_req_params = normalize_req_params( params )

      req_url = parsed_url.scheme + '://' + parsed_url.host + parsed_url.path

      base_str = [ @req_method, percent_encode( req_url ), normal_req_params ].join( '&' )

      # sign
      signature = generate_sig({
        :base_str => base_str,
        :consumer_secret => @consumer_secret,
        :token_secret => @token_secret
      })

      @params.push( 'oauth_signature=' + percent_encode( signature ) )

      return self
    end
  end

  class GeoLoc
    def initialize(api_key = 'dj0yJmk9aHhiV1JPeXpRZDRxJmQ9WVdrOVVWVnVOVWxtTldjbWNHbzlNQS0tJnM9Y29uc3VtZXJzZWNyZXQmeD00Yw--', share_key = '92d98ea113c0246d6a91b3858ea3f16ea1e87338')
      @o = OauthUtil.new
      @o.consumer_key    = api_key
      @o.consumer_secret = share_key
      @response = nil
    end

    def escape(string)
      CGI::escape(string)
    end

    def find_by_address(string)
      url = "http://query.yahooapis.com/v1/public/yql?q=SELECT%20centroid%20from%20geo.places%20WHERE%20text%3D'#{escape(string)}'&diagnostics=false"
      parsed_url = URI.parse( url )
      begin
        Net::HTTP.start( parsed_url.host ) do | http |
          req = Net::HTTP::Get.new "#{ parsed_url.path }?#{ @o.sign(url).to_query_string }"
          @response = Location.new(Hpricot.XML(http.request(req).read_body))
        end
      rescue
        ""
      end
    end

    def find(sql)
      url = "http://query.yahooapis.com/v1/public/yql?q=#{escape(sql)}"
      parsed_url = URI.parse( sql )
      Net::HTTP.start( parsed_url.host ) do | http |
        req = Net::HTTP::Get.new "#{ parsed_url.path }?#{ @o.sign(url).to_query_string }"
        @response = Location.new(Hpricot.XML(http.request(req).read_body))
      end
    end
  end

  class Location

    def initialize(response)
      @response = response
    end

    def latitude
      (@response/"centroid").each{|location| return (location/"latitude").text}
    end

    def longitude
      (@response/"centroid").each{|location| return (location/"longitude").text}
    end

    def coords
      "#{latitude}, #{longitude}"
    end
    
  end
end