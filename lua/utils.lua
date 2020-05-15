function Utils()
	local self = {}

	function self.asString(o)
	   if type(o) == 'table' then
		  local s = '{ '
		  for k,v in pairs(o) do
			 if type(k) ~= 'number' then k = '"'..k..'"' end
			 s = s .. '['..k..'] = ' .. self.asString(v) .. ','
		  end
		  return s .. '} '
	   else
		  return tostring(o)
	   end
	end

	function self.dump(o)
		print(self.asString(o));
	end

	function self.try(f, catch_f)
		local status, exception = pcall(f)
		if not status then
			catch_f(exception)
		end
	end

	function self.echo(x)
		print(x);
	end

	function self.isEmpty(v)
		return (v == nil or v == '');
	end

	function self.split(s, delimiter)
		result = {};
		for match in (s..delimiter):gmatch("(.-)"..delimiter) do
			table.insert(result, match);
		end
		return result;
	end

	function self.inherit(child, parent)
		child.base = {};
		child._parent = parent;
		local mt = { };
		mt.__index = function(t, k)
				-- if here then we know the chil doesn't have the key so we look in the parent
				if parent ~= nil then
					return parent[k];
				else
					return nil;
				end
			end
		mt.__newindex = function(t, k, v)
				if parent ~= nil and parent[k] ~= nil then
					child.base[k] = parent[k];
					parent[k] = v;
					local p = parent._parent;
					while(p ~= nil)
					do
						p[k] = v;
						p = p._parent;
					end

				end
				rawset(t, k, v);
			end
		setmetatable(child, mt);
		return child;
	end

	function self.assignCommands(obj, cmdlist, exec)
		local tbl = self.split(cmdlist, ",");

		for key, cmd in pairs(tbl) do
			obj[cmd] = function(...)
				exec(cmd, ...);--self.sendADMCommand(deviceID, cmd);
			end
		end
	end

	function self.toggleGroup(buttons, callback)
		local currentBtn;
		for i, btn in ipairs(buttons) do
			self.assignCommands(actions, btn .. "Changed", function(cmd, checked)
				if not checked then
					if btn == currentBtn then
						layout[btn].checked = true;
					end
					return;
				elseif not (btn == currentBtn) then
					local temp = currentBtn;
					currentBtn = btn;
					if temp then
						layout[temp].checked = false;
					end
				end

				if callback then
					callback(btn);
				end
			end);
		end
	end

	function self.showDialog(msg, onTapAction)
		local server = require("server");
		server.update({ 
			type = "dialog", 
			text = msg, 
			ontap = onTapAction,
			children = {
				{ type = "button", text = "OK" },
			}
		});
	end

	return self;
end