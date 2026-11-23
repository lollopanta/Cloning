-- Buffered output. Streams to disk with appendfile so memory stays flat on huge games,
-- builds the file in memory when appendfile is missing, or hands chunks to a callback.
local Env = require("env")

local Writer = {}

local FLUSH_BYTES = 4 * 1024 * 1024

function Writer.open(path, callback)
	local parts, count, pending, written = {}, 0, 0, 0
	local mode, memory

	if type(callback) == "function" then
		mode = "callback"
	elseif Env.writefile and Env.appendfile then
		mode = "stream"
		Env.writefile(path, "")
	elseif Env.writefile then
		mode = "memory"
		memory = {}
	else
		error("this executor has no writefile()", 0)
	end

	local function flush()
		if count == 0 then
			return
		end
		local chunk = table.concat(parts, "", 1, count)
		table.clear(parts)
		count, pending = 0, 0
		written += #chunk
		if mode == "stream" then
			Env.appendfile(path, chunk)
		elseif mode == "memory" then
			table.insert(memory, chunk)
		else
			callback(chunk)
		end
	end

	local writer = { mode = mode, path = path }

	function writer.push(s)
		count += 1
		parts[count] = s
		pending += #s
		if pending >= FLUSH_BYTES then
			flush()
		end
	end

	function writer.size()
		return written + pending
	end

	function writer.finish()
		flush()
		if mode == "memory" then
			Env.writefile(path, table.concat(memory))
			memory = nil
		end
		return written
	end

	function writer.abort()
		table.clear(parts)
		count, pending = 0, 0
		memory = nil
		if mode == "stream" and Env.delfile then
			pcall(Env.delfile, path)
		end
	end

	return writer
end

return Writer
