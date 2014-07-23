---IP白名单
ngx.header.content_type = "text/html";

---全局配置
PUB_MEMC_KEY = 'openapi_lua_a';
PUB_MEMC_HOST = '192.168.0.219';
PUB_MEMC_POST = 11211;
PUB_DB_HOST = '192.168.0.225';
PUB_DB_POST = 33306;
PUB_DB_DATABASE = 'hm_bossadmin';
PUB_DB_USER = 'hmeai';
PUB_DB_PASS = 'hmeai';

--获取当前项目名称
--ngx.say(ngx.var.request_uri);
local uri = ngx.var.uri;
local uri_s,uri_e = string.find(uri,'/%a*/');
local api_type = string.sub(uri,uri_s+1,uri_e-1);

--刷新参数
--local args = ngx.req.get_uri_args();
--is_refresh = args['luarefresh'];
is_refresh = ngx.var.is_refresh;

--全局json处理对象
CJSON_OBJ = require "cjson";
--ip值库
function getData(api_type)
	local memcached_keyid = PUB_MEMC_KEY..api_type;
	local memcached = require "resty.memcached";

	local memc, err = memcached:new();
	
	if not memc then
		ngx.say("failed to instantiate memc: ", err);
		return;
	end
	
	memc:set_timeout(1000); -- 1 sec

	local ok, err = memc:connect(PUB_MEMC_HOST, PUB_MEMC_POST);
	if not ok then
		ngx.say("failed to connect: ", err);
		return;
	end
	
	--获取cache
	local res, flags, err = memc:get(memcached_keyid);
	if err then
		ngx.say("failed to get dog: ", err);
		return;
	end
	--cache里无值时从db重新获取并cached
	if (not res or is_refresh == "1") then
		local mysql = require "resty.mysql";
		local db, err = mysql:new();
		if not db then
			ngx.say("failed to instantiate mysql: ", err);
			return;
		end

		db:set_timeout(1000); -- db连接超时，1 sec

		local ok, err, errno, sqlstate = db:connect{
			host = PUB_DB_HOST,
			port = PUB_DB_POST,
			database = PUB_DB_DATABASE,
			user = PUB_DB_USER,
			password = PUB_DB_PASS,
			max_packet_size = 1024 * 1024 
		}

		if not ok then
			ngx.say("failed to connect: ", err, ": ", errno, " ", sqlstate);
			return;
		end
		
		sql = 'SELECT api_type FROM openapi_white_list GROUP BY api_type';
		resOne, err, errno, sqlstate = db:query(sql);
		if not resOne then
			ngx.say("bad result: ", err, ": ", errno, ": ", sqlstate, ".");
			return;
		end
		for k,v in pairs(resOne) do
			sql = "select api_type,white_ip from openapi_white_list where api_type = '"..v.api_type.."'";
		
			res, err, errno, sqlstate = db:query(sql);
			if not res then
				ngx.say("bad result: ", err, ": ", errno, ": ", sqlstate, ".");
				return;
			end
			
			--数据格式处理
			local tab = {}
			for name, content in pairs(res) do
				tab[content.white_ip] = content.white_ip;
			end
			res = CJSON_OBJ.encode(tab);
			--生成cache
			local ok, err = memc:set(PUB_MEMC_KEY..v.api_type, res);--默认expire time为0
			if not ok then
				ngx.say("failed to set dog: ", err);
				return;
			end
		end
		
		
		
		local ok, err = db:set_keepalive(0, 100);--最多0秒闲置超时，放到连接池大小100
		if not ok then
			ngx.say("failed to set keepalive: ", err);
			return;
		end
	end
	return res;
end

--验证函数
function accessIP(api_type)
	local datas = getData(api_type);
	if api_type == "refresh" then
		ngx.say('success');
		ngx.exit(200);
	end
	local resobj = CJSON_OBJ.decode(datas)
	local this_ip = ngx.var.remote_addr;
	--ngx.say(resobj[this_ip]);
	if resobj[this_ip] == nil then
		return false;
	end
	return true;	
end

--判断
local is_acc = accessIP(api_type);

if is_acc == false then
	ngx.exit(403);
	--ngx.exit(ngx.HTTP_FORBIDDEN)--403
end