--[[载入lua文件
@param L lua状态机  
@param name 需要加载的文件名 
@return  加载成功返回0
]]
static int luaA_LoadFile(lua_State *L, const char *name)
{
	int status = -1;
	char filename[256];
	sprintf(filename, "%s.lua", name);
	FileSystem * pFileSystem = getFileSystem();
	if(pFileSystem != NULL)
	{
		Stream * pStream = pFileSystem->open(filename);
		if(pStream != NULL)
		{
			Uint32 nLength = pStream->getLength();
			if(nLength > 0)
			{
				-- 把文件读进内存
				char * pData = new char[nLength + 1]; pData[nLength] = 0;
				pStream->read(pData, nLength);
				--pStream->close();
				-- 通过内存加载文件
				status = luaL_loadbuffer(L, pData, nLength, pData);
				delete[] pData;
			}
			pStream->release();
		}
	}
	return status;
}

static int luaA_SetLoader(lua_State *L, lua_CFunction fn)
{
	lua_getglobal(L, LUA_LOADLIBNAME);
	if (lua_istable(L, -1)) 
	{
		lua_getfield(L, -1, "loaders");
		if (lua_istable(L, -1))
 		{
			lua_pushcfunction(L, fn);
			lua_rawseti(L, -2, 2);
			return 0;
		}
	}
	return -1;
}

static int luaA_DoFile(lua_State * L)
{
	size_t l;
	const char* sFileName = luaL_checklstring(L, 1, &l);
	if(sFileName != NULL )
	{
		luaA_LoadFile(L, sFileName);
		return 1;
	}
	return 0;
}

bool CLuaEngine::Create(bool bFromPackLoadLua)
{
	-- 初始化LUA库
	m_pLuaState = lua_open();
	if(m_pLuaState == NULL)
	{
		return false;
	}
	-- 初始化所有的标准库
	luaL_openlibs(m_pLuaState);
	-- 替换缺省的Lua加载函数
	luaA_SetLoader(m_pLuaState, luaA_LoadFile);
	-- 初始化一些基本的api
	lua_register(m_pLuaState, "dofile", luaA_DoFile);
	
	return true;
}