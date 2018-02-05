require 'sinatra'
require 'rest-client'

class Proxy < Sinatra::Base
	get '/favicon.ico' do
		status 204
	end

	def onRequest(requestUrl, params = nil)
		if requestUrl != ""
			begin
				if params == nil
					response = RestClient.get "http://#{requestUrl}"
				else
		    		response = RestClient.post "http://#{requestUrl}", params
		    	end
			    if response.code == 200
			    	bodyContent = response.body
			    	currentUrl = /(^http[s]?:\/\/[^\/]+)/.match(request.url).captures[0]
			    	rootRequestUrl = /([^\/]+)/.match(requestUrl).captures[0]

					bodyContent.gsub! /(?:http[s]?:\/\/)([^"]+)/, "#{currentUrl}/" + '\1'
				    bodyContent.gsub! /(?<=href=")(\/[^\/][^"\s]+)/, "#{currentUrl}/#{rootRequestUrl}" + '\1'
				    bodyContent.gsub! /(?<=src=")(\/[^\/][^"\s]+)/, "#{currentUrl}/#{rootRequestUrl}" + '\1'
				    bodyContent.gsub! /(?<=href=")(\/{2}[^"\s]+)/, "#{currentUrl}/" + '\1'.tr('/', '')
				    bodyContent.gsub! /(?<=src=")(\/{2}[^"\s]+)/, "#{currentUrl}/" + '\1'.tr('/', '')

			    	bodyContent.sub! "<head>", "<head>\n<link rel=\"shortcut icon\" href=\"#{currentUrl}/#{rootRequestUrl}/favicon.ico\" />"

			    	content_type response.headers[:content_type]
			    	body bodyContent
			    else
			    	status response.code
			    	body 'The requested page returned this response code, or the requested page could not be found.'
			    end
		    rescue => e
		    	status 500
		    	body "#{e.message}<br><br>#{e.backtrace.inspect}"
		    	#open("error.log", "w") do |f|
		    	#	f.puts "#{e.message}\n\n#{e.backtrace.inspect}"
		    	#end
		    end
		else
			status 200
			currentUrl = /(^http[s]?:\/\/[^\/]+)/.match(request.url).captures[0]
			body "<h1>Please use the URL syntax: #{currentUrl}/[desired_web_page]</h1>"
		end
	end

	get '/*' do |requestUrl|
		onRequest(requestUrl)
	end

	post '/*' do |requestUrl|
		onRequest(requestUrl, params)
	end
	
  	run! if app_file == $0
end

