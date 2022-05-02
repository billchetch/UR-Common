CMStates = {
	READY = 0,
	CONNECTING_MANAGER = 1,
	REQUESTING_CONNECTION = 2,
	CONNECTING_CLIENT = 3,
	CONNECTED_CLIENT = 4,
	ERROR = 5,
	CLOSED = 6,
}

CMErrors = {
	DESERIALIZE = 1,
	SERIALIZE = 2,
	CONNECTION = 3,
}

function CMClient(n, i, p)
	local self = {
		-- public fields go in the instance table
		name = n;
		ip = i;
		port = p;
		authToken;
		activityTimeout;
		alwaysConnect = true;
	}

	local msgUtil = MessageUtil(self.name);
	local clientMgr = SocketUtil();
	local client = SocketUtil();
	local timer = require("timer");
	local ccTID; -- connection check timer id
	local errorHandler;
	local traceHandler;
	local state = CMStates.READY;
	local messagesSent = 0;
	local messagesReceived = 0;
	local garbageReceived = 0;
	local stateChangeHandler;
	local receiveHandler;
	local receiveErrorHandler;
	local signHandler;


	function self.attachErrorHandler(h)
		errorHandler = h;
	end

	function self.attachTraceHandler(h)
		traceHandler = h;
	end

	function self.attachStateChangeHandler(h)
		stateChangeHandler = h;
	end

	function self.attachReceiveHandler(h)
		receiveHandler = h;
	end

	function self.attachReceiveErrorHandler(h)
		receiveErrorHandler = h;
	end

	function self.signHandler(h)
		signHandler = h;
	end

	function self.handleError(err, errCode)
		self.setState(CMStates.ERROR);

		if self.alwaysConnect and not self.isConnected() and not self.isConnecting() then
			self.nextCheckConnection(5000);
		end

		if errorHandler then
			errorHandler(err, erroCode);
		else
			error(err);
		end
	end

	function self.handleStateChange(oldState, newState)
		if stateChangeHandler then
			stateChangeHandler(oldState, newState);
		end
	end

	function self.trace(s, area)
		if traceHandler then
			traceHandler(s, area);
		else
			print(s);
		end
	end

	function self.setState(newState)
		local oldState = state;
		state = newState;
		
		if not (oldState == newState) then
			self.handleStateChange(oldState, newState);
		end
	end

	function self.getcs(i, p)
		if not i or not p then
			return "";
		else
			return i .. ":" .. p;
		end
	end

	-- CLIENT MANAGER CONFIG
	-- client manager erors directed to the single error handler
	clientMgr.attachErrorHandler(self.handleError);

	-- client manager requests a connection for the client from the server
	clientMgr.attachConnectHandler(function()
		self.setState(CMStates.REQUESTING_CONNECTION);
		
		local msg = msgUtil.create(MessageType.CONNECTION_REQUEST);
		if self.activityTimeout then
			msg.addValue("ActivityTimeout", self.activityTimeout);
		end

		self.trace("Client Manager Sending: " .. msg.serialize(), "sending");
		clientMgr.write(msg.serialize());
	end);

	-- client manager receives a message from server to open a new connection (the client)
	clientMgr.attachReceiveHandler(function(data)
		self.trace("Chetch Messaging receive hander recevied data");
		local message = msgUtil.deserialize(data);
		if message then
			if message.type == MessageType.CONNECTION_REQUEST_RESPONSE then
				-- connection request response message received so try and connect client
				if  message.getValue("AuthToken") then
					self.authToken = message.getValue("AuthToken"); -- if the message contains an AuthToken then update to use it
				end
				self.trace("Client manager received: " .. message.toString(), "receiving");

				clientMgr.close();
				local cip = message.getValue("IP");
				local cport = message.getValue("Port");
				
				if cip and cport then
					client.close();
					timer.timeout(function()
						self.setState(CMStates.CONNECTING_CLIENT);
						client.create(cip, cport);
						client.connect();
						self.trace("Client connecting to " .. client.cs(), "connecting");
					end, 200);
				else
					self.trace("No ip and port", "connecting");
					self.handleError("No IP and Port provided in connection request response", CMErrors.CONNECTION);
				end
			else 
				-- unrecognised message OR no auth token
				self.handleError("Client manager cannot process message " .. message.toString());
			end
		else
			-- failed to deserialise message
			self.trace("Cannot deserialize: " .. data .. ", " .. msgUtil.lastError, "connecting");
			self.close();
			self.handlError("Cannot deserialize: " .. data .. ", " .. msgUtil.lastError, CMErrors.CONNECTION);
		end
	end);

	-- when the underlying socket closes
	clientMgr.attachCloseHandler(function()
		self.trace("Client manager connection closed", "connecting");
	end);
	-- END CLIENT MANAGER CONFIG


	-- CLIENT CONFIG
	-- client errors directed to the single error handler
	client.attachErrorHandler(self.handleError);
	
	-- when the underlying client socket closes
	client.attachCloseHandler(function()
			self.setState(CMStates.CLOSED);
			self.trace("Client connection closed", "connecting");
		end);

	-- when a client connects we set state
	client.attachConnectHandler(function()
		self.setState(CMStates.CONNECTED_CLIENT);
		self.trace("Client connected");
		--self.requestServerStatus();
	end);

	-- this is for handling incoming data to the client
	client.attachReceiveHandler(function(data)
		local message = msgUtil.deserialize(data);
		if message then
			self.handleReceivedMessage(message);
		else
			garbageReceived = garbageReceived + 1;
			self.handleError("Cannot deserialize: " .. data .. ", " .. msgUtil.lastError, CMErrors.DESERIALIZE);
		end
	end);

	-- END CLIENT CONFIG


	-- CONNECTION METHODS
	-- Start the process of producing a client
	function self.requestConnection(i , p)
		if state == CMStates.CLOSED then
			self.setState(CMStates.READY);
		end

		if not (state == CMStates.READY) then
			self.handleError("Cannot request connection because not in READY state but in state " .. state, CMErrors.CONNECTION);
			return;
		end

		if i then
			self.ip = i;
		end
		if p then
			self.port = p;
		end

		self.trace("Connecting to " .. self.ip .. ":" .. self.port, "connecting");
		self.setState(CMStates.CONNECTING_MANAGER);
		clientMgr.create(self.ip, self.port);
		clientMgr.connect();
	end

	function self.close()
		self.setState(CMStates.CLOSED);
		clientMgr.close();
		client.close();
	end

	function self.isConnected()
		return state == CMStates.CONNECTED_CLIENT;
	end

	function self.isConnecting()
		return state == CMStates.CONNECTING_MANAGER or state == CMStates.CONNECTING_CLIENT;
	end
	
	function self.connect(i , p)
		if self.alwaysConnect then
			if i then
				self.ip = i;
			end
			if p then
				self.port = p;
			end
			self.trace(">>>>>>>> Connecting to " .. self.getcs(self.ip, self.port), "connecting");
			self.checkConnection();
		else
			-- self.requestConnection();
		end
	end

	function self.checkConnection()
		self.trace("Checking client connection " .. os.time(), "monitoring");
	
		local nextTimeout = 0;
		if self.isConnecting() then
			self.trace("Client is currently connecting...", "monitoring");
			nextTimeout = 200000;
		elseif self.isConnected() then
			self.trace("Client is of state connected so calling keepAlive...", "monitoring");
			self.keepAlive(); -- this can fail if state is out of sync with actual connection
			nextTimeout = 30000;
		else
			self.trace("Client is neither in state connected nor connecting", "monitoring");
			nextTimeout = 50000;
			self.close();
			if self.ip then
				if self.alwaysConnect then
					self.requestConnection();
				else
					self.trace("alwaysConnect set to false so no automatic connection will occur", "monitoring");
				end
			else
				self.trace("No IP for client so cannot start connection process", "monitoring");
			end
		end

		if nextTimeout > 0 then
			self.trace("Calling next check after " .. nextTimeout .. " ms, " .. os.time(), "monitoring");
			self.nextCheckConnection(nextTimeout);
		end
	end

	function self.keepAlive()
		self.ping();
	end

	function self.nextCheckConnection(interval)
		if ccTID then
			timer.cancel(ccTID);
		end
		ccTID = timer.timeout(self.checkConnection, interval);
	end
	-- END CONNECTION METHODS


	-- COMMUNICATION METHODS
	function self.handleReceivedMessage(message)
		if message.type == MessageType.SHUTDOWN then
			self.trace("Received server shutdown message so closing...", "receiving");
			self.close();
		end

		messagesReceived = messagesReceived + 1;

		if message.type == MessageType.STATUS_REQUEST then
			self.trace("Received status request so responding", "receiving");
			local response = msgUtil.createResponse(MessageType.STATUS_RESPONSE, message);
			response.addValue("Context", "CONTROLLER");
			response.addValue("State", "CONNECTED");
			response.addValue("MessageEncoding", "JSON");	
			response.addValue("MessagesReceived", messagesReceived);
			response.addValue("GarbageReceived", garbageReceived);
			response.addValue("MessagesSent", messagesSent);
			response.setValue("All good here");
			self.sendMessage(response);
			return;
		end

		if message.type == MessageType.PING then
			self.trace("Received status request so responding", "receiving");
			local response = msgUtil.createResponse(MessageType.PING_RESPONSE, message);
			self.sendMessage(response);
			return;
		end

		if message.type == MessageType.ERROR or message.type == MessageType.WARNING then
			if receiveErrorHandler then
				receiveErrorHandler(message);
			end
		end

		if receiveHandler then
			receiveHandler(message);
		end
	end

	function self.signMessage(msg)
		if signHandler then
			signHandler(msg, self.authToken);
		else
			msg.addValue("Signature", self.authToken .. "-" .. msg.getValue("Sender"));
		end
	end

	-- all outgoiong should go through this method
	function self.sendMessage(msg)
		if not self.isConnected() then
			self.handleError("Cannot send as state of client is " .. state .. " i.e. not connected", "connecting");
			return;
		end

		if self.authToken then
			self.signMessage(msg);
		end

		self.trace("Client sending: " .. msg.serialize(), "sending");
		client.write(msg.serialize());
		messagesSent = messagesSent + 1;
	end

	function self.send(s, t, r)
		if not self.isConnected() then
			self.handleError("Cannot send as state of client is " .. state .. " i.e. not connected", "connecting");
			return;
		end

		local mtype = t;
		if not mtype then
			mtype = MessageType.INFO;
		end
		local msg = msgUtil.create(mtype);
		if s then
			msg.setValue(s);
		end
		if r then
			msg.addValue("Target", r);
		end

		self.sendMessage(msg);
	end

	function self.requestServerStatus()
		self.send(nil, MessageType.STATUS_REQUEST);
	end

	function self.requestClientStatus(client)
		self.send(nil, MessageType.STATUS_REQUEST, client);
	end

	function self.ping()
		local msg = msgUtil.create(MessageType.PING);
		self.pingID = msg.id;
		self.sendMessage(msg);
	end

	function self.subscribe(clients)
		local msg = msgUtil.create(MessageType.SUBSCRIBE);
		msg.addValue("Clients", clients);
		self.sendMessage(msg);
	end

	function self.unsubscribe(clients)
		local msg = msgUtil.create(MessageType.UNSUBSCRIBE);
		msg.addValue("Clients", clients);
		self.sendMessage(msg);
	end

	function self.sendCommand(target, command, args)
		local msg = msgUtil.create(MessageType.COMMAND);
		local err;
		if not target then
			err = "No target supplied";
		end
		if not command then
			err = "Command not present";
		end
		if err then
			self.handleError(err);
			return;
		end

		msg.addValue("Target", target);
		msg.setValue(command);
		if args then
			msg.addValue("Arguments", args);
		end
		self.sendMessage(msg);
	end
	-- END COMMUNICATION METHODS

	return self;
end