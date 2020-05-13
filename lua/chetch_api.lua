function ChetchAPI(ep)
	local utils = Utils();

	local self = utils.inherit({
		network = {};
		services = {};
	}, RestApiUtil(ep));

	local initialisedHandler;

	function self.attachInitialisedHandler(h)
		initialisedHandler = h;
	end

	function self.get(apiCall, params, onSuccess, onError)
		if string.find(apiCall, ',', 1, true) then
			local qs = "requests="..apiCall;
			if params then
				params = qs.."&"..params
			else
				params = qs;
			end
			apiCall = "batch";
		end

		self.base.get(apiCall, params, onSuccess, onError);
	end

	function self.init()
		self.get('status,services', nil, 
				function(data)
					self.services = data.services;
					self.network = data.status;
					self.onInitialised();
				end,
				function(err)
					if err == "Timeout" then
						print("Timeout so retrying...");
						self.init();
					else
						self.handleError(err);
					end
				end
			);
	end

	function self.onInitialised()
		if initialisedHandler then
			initialisedHandler(self);
		end
	end

	return self;
end