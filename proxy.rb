require 'sinatra'
require 'rest-client'
require 'json'
require 'date'

class Proxy < Sinatra::Base
	get '/favicon.ico' do
		if File.file?("favicon.ico")
			status 200
			send_file File.join("favicon.ico")
		else
			status 204
		end
	end

	get '/bookmarks' do
		bookmarks = ENV['BOOKMARKS']
		if not bookmarks.nil?
			begin
				currentUrl = /(^http[s]?:\/\/[^\/]+)/.match(request.url).captures[0]
				bookmarksBody = ""
				bm = JSON.parse(bookmarks)
				bm.each do |k, v|
					bookmarksBody += "<li><a href=\"#{currentUrl}/#{v}\">#{k}</a></li>"
				end

				status 200
				body "<ul>#{bookmarksBody}</ul>"
			rescue
				status 500
			end
		else
			status 204
		end
	end

	def onRequest(requestUrl, params = nil)
		if requestUrl != ""
			begin
				urlToRequest = "http://#{requestUrl}"
				urlCaptures = /(http[s]?:\/\/)([^\/]+)([^$]+)/.match(request.url).captures
				currentUrl = urlCaptures[0] + urlCaptures[1]

				if params == nil
					response = RestClient.get urlToRequest
				else
		    		response = RestClient.post urlToRequest, params
		    	end
			    if response.code == 200
			    	bodyContent = response.body
			    	rootRequestUrl = /([^\/]+)/.match(requestUrl).captures[0]

					bodyContent.gsub! /(?<!href=|src=)["']\K(http[s]?:\/\/|\/\/)(?!#{Regexp.quote(currentUrl.split("//")[1])})([^"']+["'])/, "#{currentUrl}/" + '\2' # General purpose replacement (excluding href + src)

				    bodyContent.gsub! /((?:(?:href)|(?:src))=['"])((?:http[s]?:\/\/)|(?:\/{2}))/, '\1' + "#{currentUrl}/" # 2 slashes or http[s]:// after href="
				    bodyContent.gsub! /((?:(?:href)|(?:src))=['"][\/])(?!(?:http[s]?:\/\/)|(?:\/+))/, '\1' + "#{rootRequestUrl}/" # 1 slash after href="
				    bodyContent.gsub! /((?:(?:href)|(?:src))=['"])(?!(?:http[s]?:\/\/)|(?:\/+))/, '\1' + "#{currentUrl}/#{rootRequestUrl}/" # No slash after href="

			    	bodyContent.sub! "<head>", "<head>\n<link rel=\"shortcut icon\" href=\"#{currentUrl}/#{rootRequestUrl}/favicon.ico\" />"

			    	content_type response.headers[:content_type]
			    	body bodyContent
			    end
			rescue SocketError => e
				status 404
				body "<h1>Invalid URL</h1>"
			rescue RestClient::ServerBrokeConnection => e
				status e.http_code
		    	body "<h1>ServerBrokeConnection</h1><br><br>#{e.message}<br><br>#{e.backtrace.inspect}"
		    rescue RestClient::RequestFailed => e
		    	status e.http_code
		    	if [301, 302, 307].include? e.http_code
		    		redirect "#{currentUrl}/#{e.http_headers[:location].gsub!(/(http[s]?:\/\/)/, "")}"
		    	else
		    		body "<h1>RequestFailed</h1><br><br>#{e.message}<br><br>#{e.backtrace.inspect}"
		    	end
		    	#open("error.log", "a") do |f|
		    	#	f.puts "[#{Time.now.strftime("%d/%m/%Y %H:%M:%S")}] #{e.message}\n#{e.backtrace.inspect}\n\n"
		    	#end
		    rescue Errno::ECONNRESET => e
		    	status 500 
		    	body "<h1>Errno::ECONNRESET</h1><br><br>#{e.message}<br><br>#{e.backtrace.inspect}"
		    rescue Errno::ECONNABORTED => e
		    	status 500 
		    	body "<h1>Errno::ECONNABORTED</h1><br><br>#{e.message}<br><br>#{e.backtrace.inspect}"  	
		    end
		else
			status 200
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

