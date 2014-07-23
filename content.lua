ngx.header.content_type = "text/html";
--先从memcache提取数据

local args = ngx.req.get_uri_args()

if args["appleid"] == nil then
	return
end

local memcached = require "resty.memcached"
local memc, err = memcached:new()
if not memc then
	ngx.say("failed to instantiate memc: ", err)
	return
end


memc:set_timeout(1000) -- 1 sec

local ok, err = memc:connect("192.168.0.219", 11211)
if not ok then
	ngx.say("failed to connect: ", err)
	return
end

local res, flags, err = memc:get(args["appleid"] )
if err then
	ngx.say("failed to get dog: ", err)
	return
end

--数据不在memcache中 从数据库提取并放到memcache
if not res then
	
	local mysql = require "resty.mysql"
	local db, err = mysql:new()
	if not db then
		ngx.say("failed to instantiate mysql: ", err)
		return
	end

	db:set_timeout(1000) -- 1 sec

	local ok, err, errno, sqlstate = db:connect{
		host = "192.168.0.225",
		port = 33306,
		database = "hm_bossadmin",
		user = "hmeai",
		password = "hmeai",
		max_packet_size = 1024 * 1024 
	}

	if not ok then
		ngx.say("failed to connect: ", err, ": ", errno, " ", sqlstate)
		return
	end

	--ngx.say("connected to mysql.")

	sql = "select * from eai_admin_user where admin_id = "..args["id"]

	res, err, errno, sqlstate = db:query(sql)
	if not res then
		ngx.say("bad result: ", err, ": ", errno, ": ", sqlstate, ".")
		return
	end

	local cjson = require "cjson"
	ngx.say(cjson.encode(res))

	local ok, err = memc:set(args["id"], cjson.encode(res))
	if not ok then
		ngx.say("failed to set dog: ", err)
		return
	end

	local ok, err = db:set_keepalive(0, 100)
	if not ok then
		ngx.say("failed to set keepalive: ", err)
		return
	end

	return
end

ngx.say(res)

memc:set_keepalive(0, 100)