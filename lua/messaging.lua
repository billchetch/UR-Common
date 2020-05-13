-- Do not change the value of these message types as they corresopnd to chetch messaging types
MessageType = {
		INFO = 3,
		WARNING = 4,
        ERROR = 5,
		PING = 6,
        PING_RESPONSE = 7,
		STATUS_REQUEST = 8,
        STATUS_RESPONSE = 9,
		COMMAND = 10,
        ERROR_TEST = 11,
		DATA = 18,
        CONNECTION_REQUEST = 19,
        CONNECTION_REQUEST_RESPONSE = 20,
		SHUTDOWN  = 21,
        SUBSCRIBE = 22,
        UNSUBSCRIBE = 23,
        COMMAND_RESPONSE = 24,
		NOTIFICATION = 26
}

function Message(t, id)
	-- the new instance
	if not id then
		id = "UR:".. os.time().."-"..math.random(1, 32767);
	end

	local self = {
		-- public fields go in the instance table
		id = id;
		type = t;
	}

	local values = {};
	local parser = require("data");
	local utils = Utils(); -- NOTE: requires utils from common to be included

	function self.addValue(key, val)
		if not key then
			values["Value"] = val;
		else
			values[key] = val;
		end
	end

	function self.setValue(val)
		self.addValue(nil, val);
	end

	function self.getValue(key)
		if not key then
			return values["Value"];
		else
			return values[key];
		end
	end

	function self.serialize()
		local vals = {};
		for k,v in pairs(values) do
			vals[k] = v;
		end
		vals["Type"] = self.type;
		vals["ID"] = self.id;
		local s = parser.tojson(vals);
		return s;
	end

	function self.deserialize(s)
		if not s then
			return nil;
		end

		local vals = nil;
		local parseError = nil;
		utils.try(function()
				vals = parser.fromjson(s);
			end, function(err)
				parseError = err;
			end);

		if parseError then
			return parseError;
		end
		
		self.type = vals["Type"];
		self.id = vals["ID"];
		for k,v in pairs(vals) do
			if not (k == "Type") and not (k == "ID") then
				self.addValue(k, v);
			end
		end
		return nil;
	end

	function self.toString()
		local s;
		local lf = "\n";
		s = "ID: " ..self.id .. ", Type: " .. self.type .. lf;
		for k,v in pairs(values) do
			if not (k == "Type") then
				local val;
				if type(v) == 'table' then
					val = "[table]";
				else
					val = v;
				end
				s = s .. k .. " = " .. val .. lf;
			end
		end
		return s;
	end

	return self
end

function MessageUtil(sender)
	local self = {
		lastError = "";
		defaultSender = sender;
	};

	function self.create(t, id)
		local m = Message(t, id);
		m.addValue("Sender", self.defaultSender);
		return m;
	end

	function self.createResponse(t, msg)
		local m = self.create(t);
		m.addValue("ResponseID", msg.id);
		m.addValue("Target", msg.getValue("Sender"));
		m.addValue("ConnectionID", "ID:" .. self.defaultSender);
		m.addValue("Name", self.defaultSender);
		return m
	end

	function self.deserialize(s)
		local m = Message();
		local err = m.deserialize(s);
		if err then
			lastError = err;
			return nil;
		else
			return m;
		end
	end

	return self
end