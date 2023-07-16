local Promise = require(script.Parent.Parent.Promise)
local types = require(script.Parent.Parent.types)
local setInterval = require(script.Parent.Parent.utils.setInterval)

--[=[
	Creates a broadcast receiver object that can be used to dispatch actions
	broadcasted by the server.
	@param options The options for the broadcast receiver.
	@return The broadcast receiver.
]=]
local function createBroadcastReceiver(options: types.BroadcastReceiverOptions): types.BroadcastReceiver
	local requestState = options.requestState
	local requestInterval = options.requestInterval or 5

	local receiver = {} :: types.BroadcastReceiver
	local rootProducer: types.Producer?

	local function merge(state)
		assert(rootProducer, "Failed to apply receiver middleware")

		local nextState = table.clone(rootProducer:getState())

		for key, value in state do
			nextState[key] = value
		end

		rootProducer:setState(nextState)
	end

	local function requestMerge()
		local value = requestState()

		if Promise.is(value) then
			value:andThen(merge)
		else
			merge(value)
		end
	end

	function receiver:dispatch(actions: { types.BroadcastAction })
		assert(rootProducer, "Cannot dispatch actions before the middleware is applied")

		local dispatchers = rootProducer:getDispatchers()

		for _, action in actions do
			if dispatchers[action.name] then
				dispatchers[action.name](table.unpack(action.arguments))
			end
		end
	end

	function receiver.middleware(producer)
		rootProducer = producer

		if requestInterval > 0 then
			setInterval(requestMerge, requestInterval)
		end

		requestMerge()

		return function(dispatch)
			return dispatch
		end
	end

	return receiver
end

return createBroadcastReceiver
