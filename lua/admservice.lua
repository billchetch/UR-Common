function ADMServiceClient(serviceName)
	local utils = Utils();

	local self = utils.inherit({
		admReady = false;
	}, ServiceClient(serviceName));
	
	local admReadyHandler;

	function self.attachADMReadyHandler(h)
		admReadyHandler = h;
	end


	function self.onServiceReady(message)
		self.base.onServiceReady(message);

		local state = message.getValue("ADMState");
		if state then
			if state == "DEVICE_CONNECTED" then
				self.admReady = true;
			else
				self.admReady = false;
			end

			if admReadyHandler then
				admReadyHandler(self.admReady, state);
			end
		else
			self.handleError("No AMDState key");
		end
	end

	function self.sendADMCommand(deviceID, command, arguments)
		local scmd;
		if deviceID then
			scmd = "adm:"..deviceID..":"..command;
		else
			scmd = "adm:"..command;
		end

		self.sendServiceCommand(scmd, arguments);
	end

	function self.admStatus()
		self.trace("ADM status called");
		self.sendADMCommand(nil, "status");
	end

	function self.admPing()
		self.trace("ADM ping called");
		self.sendADMCommand(nil, "ping");
	end

	function self.admBlink(rpt, delay)
		self.trace("ADM blink called");
		self.sendADMCommand(nil, "blink", {rpt, delay});
	end
	
	return self;
end