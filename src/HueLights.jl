module HueLights

using HTTP, JSON, Colors

"""
    get_bridge_ip()

Get the IP address of the Hue bridge. First check the environment variables,
and if key `HUE_BRIDGE_IP` is not present, use the Philips Hue website. Return
the address as a string or throw an error if none is found.
"""
function get_bridge_ip()
	if haskey(ENV, "HUE_BRIDGE_IP")
		return ENV["HUE_BRIDGE_IP"]
	end
	r = HTTP.get("https://www.meethue.com/api/nupnp")
	if r.status != 200
		error("Did not get successful response from https://www.meethue.com/api/nupnp")
	end
	# body should be a 1-element vector,
	# something like [{"id":"012345abcde","internalipaddress":"192.168.0.102"}]
	js = r.body |> String |> JSON.parse 
	if length(js) < 1
		error("Did not find any Hue bridges.")
	end
	return js[1]["internalipaddress"]
end

function hue_api_addr()
	return "http://" * ENV["HUE_BRIDGE_IP"] * "/api/" * ENV["HUE_USERNAME"]
end

const HUE = hue_api_addr()

function get_hue_lights()
	r = HTTP.get(HUE * "/lights")
	return get_hue_lights(String(r))
end
# get light names given the string describing all lights
function get_hue_lights(str::String)
	dict = JSON.parse(str)
	lightind = 1
	lightnames = String[]
	while haskey(dict, string(lightind))
		push!(lightnames, dict[string(lightind)]["name"])
		lightind += 1
	end
	return lightnames
end

function set_light_state!(light::Int, body::Dict)
	HTTP.put(HUE * "/lights/$(light)/state"; body = JSON.json(body))
end
	

# brightness false by default because it seems like not all color specs
# can express the same brightness range, e.g. RGB(0,0,1) gives a brightness Y of
# ~.07 on a [0,1] scale.
function set_light_color!(light, color; brightness = false)
	cie = convert(xyY, color)
	if cie.Y == 0 # no brightness, light should be off
		set_light_state!(light, Dict("on" => false))
	end
	state = Dict{String, Any}("xy" => [cie.x, cie.y], "on" => true)
	if brightness
		state["bri"] = round(Int, 254 * cie.Y)
	end
	set_light_state!(light, state)
end

function get_light_state(light::Int)
	d = JSON.parse(String(HTTP.get(HUE * "/lights/$(light)")))
	return d["state"]
end

macro huewarn(light, expr)
	quote
		local val = $(esc(expr))
		@schedule begin
			l = $(light)
			state = get_light_state(l)
			set_light_state!(l, Dict("on" => true, "bri" => 254))
			set_light_color!(l, RGB(0,1,0))
			sleep(1)
			set_light_color!(l, RGB(1,0,0))
			sleep(1)
			set_light_color!(l, RGB(0,1,0))
			sleep(1)
			set_light_state!(l, state)
		end
		return val
	end
end

end # module