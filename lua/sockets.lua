SocketState = {RESET = 0, READY_TO_CONNECT = 1, CONNECTING = 2, CONNECTED = 3};

function SocketUtil(hst, prt)
	-- the new instance
	local self = {
		-- public fields go in the instance table
	}

	-- private fields are implemented using locals
	-- they are faster than table access, and are truly private, so the code that uses your class can't get them
	local host = hst;
	local port = prt;
	local factory = require("socket");
	local buffer = require("buffer");
	local socket;
	local status = SocketState.RESET;
	local errorHandler;
	local receiveHandler;
	local disconnectHandler;
	local connectHandler;

	function self.handleError(err)
		status = SocketState.RESET;
		if errorHandler then
			errorHandler(err);
		else
			error("SocketUtil:handleError " .. err);
		end
	end

	function self.handleData(data)
		print("SocketUtil::handeData: recevied data");
		if receiveHandler then
			receiveHandler(data);
		end
	end

	function self.handleClose()
		print("SocketUtil::handleClose Closed");
		status = SocketState.RESET;
		if closeHandler then
			closeHandler();
		end
	end

	function self.handleConnect()
		if status == SocketState.CONNECTING then
			print("SocketUtil::handleConnect: Connected");
			status = SocketState.CONNECTED;
			if connectHandler then
				connectHandler();
			end
		else
			status = SocketState.RESET;
			self.handleError("SocketUtil:connect status is not 2");
		end 
	end

	function self.attachErrorHandler(h)
		errorHandler = h;
	end

	function self.attachReceiveHandler(h)
		receiveHandler = h;
	end

	function self.attachCloseHandler(h)
		closeHandler = h;
	end

	function self.attachConnectHandler(h)
		connectHandler = h;
	end

	function self.create(h, p)
		if h then host = h; end
		if p then port = p; end

		-- create new socket instance and set status
		socket = nil;
		socket = factory.new();
		status = SocketState.READY_TO_CONNECT;

		-- add event handlers
		socket:onconnect(self.handleConnect);
		socket:onerror(self.handleError);
		socket:onclose(self.handleClose);
		socket:ondata(self.handleData);
	end

	function self.connect()
		if not (status == SocketState.READY_TO_CONNECT) then
			return self.handleError("Status is not 1");
		else
			if not socket then
				return self.handleError("No socket");
			end
			if not host then
				return self.handleError("No host");
			end
			if not port then
				return self.handleError("No port");
			end

			status = SocketState.CONNECTING;
			-- print("Connecting to " .. host .. ":" .. port);
			socket:connect(host, port);
		end
	end

	function self.write(data)
		if not (status == SocketState.CONNECTED) then
			return self.handleError("Write status is not CONNECTED");
		end

		socket:write(data);	
	end

	function self.writeLine(data)
		self.write(data .. "\n");
	end

	function self.close()
		if status == SocketState.CONNECTED then
			status = SocketState.RESET;
			socket:close();
		end
	end

	function self.getStatus()
		return status;
	end

	function self.getSocket()
		return socket;
	end

	function self.cs()
		return host .. ":" .. port;
	end

	-- return the instance
	return self
end