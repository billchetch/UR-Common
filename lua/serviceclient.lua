function ServiceClient(serviceName)
	local utils = Utils();

	local self = utils.inherit({
		service = serviceName;
		serviceReady = false;
	}, CMClient("UR-"..serviceName));
	
	function self.handleStateChange(oldState, newState)
		self.base.handleStateChange(oldState, newState);
		
		if newState == CMStates.CONNECTED_CLIENT then
			self.requestServiceStatus();
		end
	end
	
	local serviceReadyHandler;

	function self.attachServiceReadyHandler(h)
		serviceReadyHandler = h;
	end

	function self.onServiceReady(message)
		self.serviceReady = true;

		if serviceReadyHandler then
			serviceReadyHandler(self.serviceReady);
		end
	end

	function self.keepAlive()
		self.requestServiceStatus();
	end

	function self.handleReceivedMessage(message)
		self.base.handleReceivedMessage(message);

		if message.type == MessageType.STATUS_RESPONSE and message.getValue("Sender") == self.service and not self.serviceReady then
			self.onServiceReady(message);
		end
	end

	function self.connect(i , p)
		self.base.connect(i, p);
		self.serviceReady = false;
		if self.isConnected() then
			self.requestServiceStatus();
		end
	end

	function self.requestServiceStatus()
		self.trace("Requesting service status  for " .. self.service);
		self.requestClientStatus(self.service);
	end

	function self.sendServiceCommand(command, argumets)
		self.sendCommand(self.service, command, arguments);
	end
	
	return self;
end