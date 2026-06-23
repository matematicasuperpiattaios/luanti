-- Blocking "sleep" implemented as a fetch_sync that runs out its timeout.
-- Runs inside core.handle_async (worker thread), where fetch_sync is allowed.
-- NOTE: this function is serialised (string.dump) into a separate Lua state,
-- so it must use only globals + its params, never upvalues.
local function locked_sleep(params)
	if (core ~= nil) then
		local http = core.get_http_api()
		-- timeout must be greater than 0 otherwise fetch_sync uses its default
		local wt = params.secs > 0 and params.secs or 5
		core.log("locked_sleep: " .. tostring(wt) .. "s")

		-- loop multiple times cause the maximum timeout is 10
		local i = math.floor(wt / 10)
		while i > 0 do
			i = i - 1
			wt = wt - 10
			http.fetch_sync({url = "https://wiscoms.matematicasuperpiatta.it:8888", timeout = 10})
		end
		if wt > 0 then
			http.fetch_sync({url = "https://wiscoms.matematicasuperpiatta.it:8888", timeout = wt})
		end
	end
end

-- The real "server ready" callback. It cannot be threaded through the async
-- boundary (Luanti 5.16 serialises async params and functions are not
-- serialisable), so keep it here at module scope: wait_go is re-entered as the
-- async callback in the main Lua state and re-reads this.
local pending_callback

function wait_go(callback)
	if callback then
		pending_callback = callback
	end

	if (handshake.roadmap.server.ip == nil) then
		if lambda_error then
			return
		end

		if lambda_read then
			handshake:launchpad()
			lambda_read = false
		end

		local wait = 0.5
		if lambda_waiting then
			wait = 5
			core.log("wait_go [waiting_lambda]: " .. tostring(wait) .. "s")
		else
			lambda_read = true
			wait = handshake.roadmap.server.waiting_time
			core.log("wait_go: " .. tostring(wait) .. "s")
		end

		-- update flavor time label
		update_flavor()

		core.handle_async(locked_sleep, {secs = wait}, wait_go)
	else
		pending_callback(core, handshake, gamedata)
	end
end
