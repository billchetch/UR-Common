
function RestApiUtil(ep)
	-- the new instance
	local self = {
		-- public fields go in the instance table
		endpoint = ep;
	}

	local utils = Utils(); -- NOTE: requires utils from common to be included
	local http = require("http");
	local parser = require("data");
	local errorHandler;
	local responseHandler;

	function self.handleError(err)
		if errorHandler then
			errorHandler(err);
		else
			error("RestApitUtil:handleError " .. err);
		end
	end

	function self.parseResponse(resp)
		local parseResult = nil;
		local parseError = nil;
		utils.try(function()
				parseResult = parser.fromjson(resp);
			end, function(err)
				parseError = err;
			end);

		if parseError then
			return nil;
		else
			return parseResult;
		end
	end

	function self.handleResponse(err, resp)
		if err then
			self.handleError(err);
			return;
		end

		if resp == nil or resp == '' then
			self.handleError("Empty response");
			return;
		end

		--TODO error handling on failed parsing
		local parsedData = self.parseResponse(resp);
		if not parsedData then
			self.handleError("Failed to parse response");
			return;
		end

		--print("Received a response");
		if responseHandler then
			local rerr = responseHandler(parsedData);
			if rerr then
				self.handleError(rerr);
			end
			responseHandler = nil;
		end
	end

	function self.attachErrorHandler(h)
		errorHandler = h;
	end

	function self.get(apiCall, params, onSuccess, onError)
		if not self.endpoint then
			return self.handleError("No endpoint specified");
		end

		if not apiCall then
			return self.handleError("Cannot have an empty api call");
		end

		local url = self.endpoint .. "/" .. apiCall;

		if params then
			local qs = "";
			if type(params) == "table" then
				--todo: utils function to turn table to query string 
			else
				qs = params;
			end
			url = url .. "?" .. qs;
		end

		-- print("Getting "..url);
		http.get(url, function(err, resp)
				if onError and err then
					onError(err);
				else 
					if onSuccess then
						responseHandler = onSuccess;
					end
					self.handleResponse(err, resp);
				end
			end);
	end

	return self
end