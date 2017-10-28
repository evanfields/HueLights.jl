module HueLights

using HTTP, JSON, Colors

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

function set_light_green!(light::Int)
	d = Dict("on" => true, "bri" => 254, "hue" => 25500, "sat" => 254)
	set_light_state!(light, d)
end

function get_light_state(light::Int)
	d = JSON.parse(String(HTTP.get(HUE * "/lights/$(light)")))
	return d["state"]
end

macro huewarn(light, expr)
	quote
		local val = $(esc(expr))
		set_light_green!($(light))
		return val
	end
end

end # module