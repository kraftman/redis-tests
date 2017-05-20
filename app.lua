local lapis = require("lapis")
local app = lapis.Application()
local redis = require 'resty.redis'

local redis = require "resty.redis"

local ffi = require("ffi")
ffi.cdef[[
	typedef long time_t;

 	typedef struct timeval {
		time_t tv_sec;
		time_t tv_usec;
	} timeval;

	int gettimeofday(struct timeval* t, void* tzp);
]]

local gettimeofday_struct = ffi.new("timeval")
local function gettimeofday()
 	ffi.C.gettimeofday(gettimeofday_struct, nil)
 	return tonumber(gettimeofday_struct.tv_sec) * 1000000 + tonumber(gettimeofday_struct.tv_usec)
end

app:get("/", function()
  return "Welcome to Lapis " .. require("lapis.version")
end)

local function RunTests(host, port)
  -- run 10000 operations
  -- count how long it took

  local red = redis:new()
  local ok, err  = red:connect(host, port)
  if not ok then
    ngx.say('failed to connect')
    return
  end
  local count = 1000
  local a = gettimeofday()
  for i = 1, count do
    red:set('key'..i,'value'..i)
  end
  local b = gettimeofday()
  print(count/(b-a)..' requests per second')
  for i = 1, count do
    red:get('key'..i)
  end




end

app:get('/spiped',function()
  RunTests()
end)

return app
