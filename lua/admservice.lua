function ADMServiceClient(serviceName)
	local utils = Utils();

	local self = utils.inherit({
		
	}, ServiceClient(serviceName));
	
	

	function self.connect(i, p)
		self.base.connect(i, p);
		
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