local lapis = require("lapis")
local app = lapis.Application()
local redis = require 'resty.redis'

local redis = require "resty.redis"

local remoteIP = ''

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
  ngx.say(host, ' ', port, ':</br>')

  local red = redis:new()
  local ok, err  = red:connect(host, port)
  if not ok then
    ngx.say('failed to connect')
    return
  end
  local count = 1000

  local a = gettimeofday()
  local a1 = ngx.time()
  for i = 1, count do
    red:set('key'..i,'value'..i)
  end
  local b = gettimeofday()

  ngx.say(count/((b-a)/1000000)..' requests per second</br>')

  for i = 1, count do
    red:del('key'..i)
  end
  a = gettimeofday()
  ngx.say(count/((a-b)/1000000)..' deletes per second</br>')

end

local function RunPiped(host, port)

  ngx.say('pipelined: ', host, ' ', port, ':</br>')

	local red = redis:new()
  local ok, err  = red:connect(host, port)
  if not ok then
    ngx.say('failed to connect')
    return
  end
  local count = 0
  local a = gettimeofday()

  for i = 1, 1000 do
	  red:init_pipeline()

	  for j = 1, 1000 do
	  	count = count +1
	    red:set('key'..i*j,'value'..i*j)
	  end
	  local ok, err = red:commit_pipeline()
	  if ok then
	  	--print('success')
	  else
	  	--print(err)
	  end
	end

  local b = gettimeofday()
  ngx.say('pipelined: ', count/((b-a)/1000000),'requests per second </br>')

end

function RedisAsync(_,id,host,port)

	local red = redis:new()
	red:set_timeout(60000)
  local ok, err  = red:connect(host, port)
  if not ok then
    print('failed to connect: ',err)
    return
  end
  local count = 1000

  local a = gettimeofday()
  for i = 1, count do
    red:set('key:'..id..':'..i,'value'..i)
  end

  ngx.shared.tallies:set('thread:'..id, ((count)/((gettimeofday() - a)/1000000)))


  for i = 1, count do
    red:del('key:'..id..':'..i)
  end
  red:set_keepalive(1000, 1000)

end

function RedisAsyncPiped(_,id,host,port)

	local red = redis:new()
	red:set_timeout(120000)
  local ok, err  = red:connect(host, port)
  if not ok then
    print('failed to connect: ',err)
    return
  end
  local count = 1000
  local size = 1000

  local a = gettimeofday()
  for j = 1, count do
	  red:init_pipeline()
	  for i = 1, size do
	    red:set('key:'..id..':'..i*j,'value'..i*j)
	  end

	 red:commit_pipeline()
  end

  ngx.shared.tallies:set('thread:'..id, ((count*size)/((gettimeofday() - a)/1000000)))



  for i = 1, count do
    red:del('key:'..id..':'..i*j)
  end
  red:set_keepalive(1000, 1000)

end

function RunAsync(host,port)
	-- send to a few threads
	-- have the threads log the time taken
	-- check when they are all done
	-- combine resulst

	for i = 1, 300 do
		ngx.shared.tallies:set('thread:'..i, 0)
		ngx.timer.at(0, RedisAsync, i,host, port)
	end


end

function RunAsyncPiped(host,port)
	-- send to a few threads
	-- have the threads log the time taken
	-- check when they are all done
	-- combine resulst
	for i = 1, 300 do
		ngx.shared.tallies:set('thread:'..i, 0)
		ngx.timer.at(0, RedisAsyncPiped, i,host, port)
	end


end




app:get('/spiped',function()
   RunTests('127.0.0.1', 6379)
   RunTests('127.0.0.1', 16379)
   RunPiped('127.0.0.1',6379)
   RunPiped('127.0.0.1',16379)


  RunTests(remoteIP, 6379)

  RunPiped(remoteIP,6379)


end)

app:get('/async', function()
	RunAsync('127.0.0.1', 6379)
end)

app:get('/asyncpiped', function()
	RunAsync('127.0.0.1', 6379)
end)

app:get('/results', function()
	local total = 0
	for i = 1, 300 do
		total = total + ngx.shared.tallies:get('thread:'..i)
	end
	ngx.say(total)
end
)

return app
