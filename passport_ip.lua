---按照ip地址拦截请求

ngx.header.content_type = "text/html";

---全局配置
PUB_MEMC_KEY = 'passport_ip_';
PUB_MEMC_HOST = '192.168.0.219';
PUB_MEMC_POST = 11211;
PUB_MEMC_TIME = 86400;
PUB_MAX_NUM = 50;

--获取外网请求IP地址
local uri = ngx.var.request_uri;
--ngx.say(uri);
uri = string.sub(uri,1,31);

local ip = ngx.var.remote_addr;

function getAccessNumByIP(ip)
	local memcached = require "resty.memcached";

	local memc, err = memcached:new();
	
	if not memc then
		ngx.say("failed to instantiate memc: ", err);
		return 'error';
	end
	
	memc:set_timeout(1000); --连接超时， 1 sec

	local ok, err = memc:connect(PUB_MEMC_HOST, PUB_MEMC_POST);
	if not ok then
		ngx.say("failed to connect: ", err);
		return 'error';
	end
	
	local memcached_keyid = PUB_MEMC_KEY..ip;
	--获取cache
	local res, flags, err = memc:get(memcached_keyid);
	if err then
		ngx.say("failed to get dog: ", err);
		return 'error';
	end
	
	if not res then
		res = 1;
	else
		res = res + 1;
	end
	
	
	local ok, err = memc:set(memcached_keyid, res, PUB_MEMC_TIME);--默认expire time为0
	if not ok then
		ngx.say("failed to set dog: ", err);
		return 'error';
	end
			
	return res;
end

--判断
if uri == "/register/sendValidateCode.html" then
	local access_num = getAccessNumByIP(ip);
	if access_num > PUB_MAX_NUM then
		ngx.say('{"success":false,"msg":"请求过于频繁，请稍后再处理!"}');
		ngx.exit(200);
		--ngx.exit(ngx.HTTP_FORBIDDEN)--403
	end
end


