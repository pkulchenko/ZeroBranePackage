-- Copyright 2015 Paul Kulchenko, ZeroBrane LLC; All rights reserved

local redis = (function() -- redis-lua module start ----------------------------
local redis = {
    _VERSION     = 'redis-lua 2.0.5-dev',
    _DESCRIPTION = 'A Lua client library for the redis key value storage system.',
    _COPYRIGHT   = 'Copyright (C) 2009-2012 Daniele Alessandri',
}

local unpack = _G.unpack or table.unpack
local network, request, response = {}, {}, {}

local defaults = {
    host        = '127.0.0.1',
    port        = 6379,
    tcp_nodelay = true,
    path        = nil,
}

local function merge_defaults(parameters)
    if parameters == nil then
        parameters = {}
    end
    for k, v in pairs(defaults) do
        if parameters[k] == nil then
            parameters[k] = defaults[k]
        end
    end
    return parameters
end

local function parse_boolean(v)
    if v == '1' or v == 'true' or v == 'TRUE' then
        return true
    elseif v == '0' or v == 'false' or v == 'FALSE' then
        return false
    else
        return nil
    end
end

local function toboolean(value) return value == 1 end

local function sort_request(client, command, key, params)
    --[[ params = {
        by    = 'weight_*',
        get   = 'object_*',
        limit = { 0, 10 },
        sort  = 'desc',
        alpha = true,
    } ]]
    local query = { key }

    if params then
        if params.by then
            table.insert(query, 'BY')
            table.insert(query, params.by)
        end

        if type(params.limit) == 'table' then
            -- TODO: check for lower and upper limits
            table.insert(query, 'LIMIT')
            table.insert(query, params.limit[1])
            table.insert(query, params.limit[2])
        end

        if params.get then
            if (type(params.get) == 'table') then
                for _, getarg in pairs(params.get) do
                    table.insert(query, 'GET')
                    table.insert(query, getarg)
                end
            else
                table.insert(query, 'GET')
                table.insert(query, params.get)
            end
        end

        if params.sort then
            table.insert(query, params.sort)
        end

        if params.alpha == true then
            table.insert(query, 'ALPHA')
        end

        if params.store then
            table.insert(query, 'STORE')
            table.insert(query, params.store)
        end
    end

    request.multibulk(client, command, query)
end

local function zset_range_request(client, command, ...)
    local args, opts = {...}, { }

    if #args >= 1 and type(args[#args]) == 'table' then
        local options = table.remove(args, #args)
        if options.withscores then
            table.insert(opts, 'WITHSCORES')
        end
    end

    for _, v in pairs(opts) do table.insert(args, v) end
    request.multibulk(client, command, args)
end

local function zset_range_byscore_request(client, command, ...)
    local args, opts = {...}, { }

    if #args >= 1 and type(args[#args]) == 'table' then
        local options = table.remove(args, #args)
        if options.limit then
            table.insert(opts, 'LIMIT')
            table.insert(opts, options.limit.offset or options.limit[1])
            table.insert(opts, options.limit.count or options.limit[2])
        end
        if options.withscores then
            table.insert(opts, 'WITHSCORES')
        end
    end

    for _, v in pairs(opts) do table.insert(args, v) end
    request.multibulk(client, command, args)
end

local function zset_range_reply(reply, command, ...)
    local args = {...}
    local opts = args[4]
    if opts and (opts.withscores or string.lower(tostring(opts)) == 'withscores') then
        local new_reply = { }
        for i = 1, #reply, 2 do
            table.insert(new_reply, { reply[i], reply[i + 1] })
        end
        return new_reply
    else
        return reply
    end
end

local function zset_store_request(client, command, ...)
    local args, opts = {...}, { }

    if #args >= 1 and type(args[#args]) == 'table' then
        local options = table.remove(args, #args)
        if options.weights and type(options.weights) == 'table' then
            table.insert(opts, 'WEIGHTS')
            for _, weight in ipairs(options.weights) do
                table.insert(opts, weight)
            end
        end
        if options.aggregate then
            table.insert(opts, 'AGGREGATE')
            table.insert(opts, options.aggregate)
        end
    end

    for _, v in pairs(opts) do table.insert(args, v) end
    request.multibulk(client, command, args)
end

local function mset_filter_args(client, command, ...)
    local args, arguments = {...}, {}
    if (#args == 1 and type(args[1]) == 'table') then
        for k,v in pairs(args[1]) do
            table.insert(arguments, k)
            table.insert(arguments, v)
        end
    else
        arguments = args
    end
    request.multibulk(client, command, arguments)
end

local function hash_multi_request_builder(builder_callback)
    return function(client, command, ...)
        local args, arguments = {...}, { }
        if #args == 2 then
            table.insert(arguments, args[1])
            for k, v in pairs(args[2]) do
                builder_callback(arguments, k, v)
            end
        else
            arguments = args
        end
        request.multibulk(client, command, arguments)
    end
end

local function parse_info(response)
    local info = {}
    local current = info

    response:gsub('([^\r\n]*)\r\n', function(kv)
        if kv == '' then return end

        local section = kv:match('^# (%w+)$')
        if section then
            current = {}
            info[section:lower()] = current
            return
        end

        local k,v = kv:match(('([^:]*):([^:]*)'):rep(1))
        if k:match('db%d+') then
            current[k] = {}
            v:gsub(',', function(dbkv)
                local dbk,dbv = kv:match('([^:]*)=([^:]*)')
                current[k][dbk] = dbv
            end)
        else
            current[k] = v
        end
    end)

    return info
end

local function scan_request(client, command, ...)
    local args, req, params = {...}, { }, nil

    if command == 'SCAN' then
        table.insert(req, args[1])
        params = args[2]
    else
        table.insert(req, args[1])
        table.insert(req, args[2])
        params = args[3]
    end

    if params and params.match then
        table.insert(req, 'MATCH')
        table.insert(req, params.match)
    end

    if params and params.count then
        table.insert(req, 'COUNT')
        table.insert(req, params.count)
    end

    request.multibulk(client, command, req)
end

local zscan_response = function(reply, command, ...)
    local original, new = reply[2], { }
    for i = 1, #original, 2 do
        table.insert(new, { original[i], tonumber(original[i + 1]) })
    end
    reply[2] = new

    return reply
end

local hscan_response = function(reply, command, ...)
    local original, new = reply[2], { }
    for i = 1, #original, 2 do
        new[original[i]] = original[i + 1]
    end
    reply[2] = new

    return reply
end

local function load_methods(proto, commands)
    local client = setmetatable ({}, getmetatable(proto))

    for cmd, fn in pairs(commands) do
        if type(fn) ~= 'function' then
            redis.error('invalid type for command ' .. cmd .. '(must be a function)')
        end
        client[cmd] = fn
    end

    for i, v in pairs(proto) do
        client[i] = v
    end

    return client
end

local function create_client(proto, client_socket, commands)
    local client = load_methods(proto, commands)
    client.error = redis.error
    client.network = {
        socket = client_socket,
        read   = network.read,
        write  = network.write,
    }
    client.requests = {
        multibulk = request.multibulk,
    }
    return client
end

-- ############################################################################

function network.write(client, buffer)
    local _, err = client.network.socket:send(buffer)
    if err then return client.error(err) end
end

function network.read(client, len)
    if len == nil then len = '*l' end
    local line, err = client.network.socket:receive(len)
    if not err then return line else return client.error('connection error: ' .. err) end
end

-- ############################################################################

function response.read(client)
    local payload = client.network.read(client)
    local prefix, data = payload:sub(1, -#payload), payload:sub(2)

    -- status reply
    if prefix == '+' then
        if data == 'OK' then
            return true
        elseif data == 'QUEUED' then
            return { queued = true }
        else
            return data
        end

   -- error reply
    elseif prefix == '-' then
        return client.error('redis error: ' .. data)

   -- integer reply
    elseif prefix == ':' then
        local number = tonumber(data)

        if not number then
            if data == 'nil' then
                return nil
            end
            return client.error('cannot parse ' .. data .. ' as a numeric response.')
        end

        return number

   -- bulk reply
    elseif prefix == '$' then
        local length = tonumber(data)

        if not length then
            return client.error('cannot parse ' .. length .. ' as data length')
        end

        if length == -1 then
            return nil
        end

        local nextchunk = client.network.read(client, length + 2)

        return nextchunk:sub(1, -3)

   -- multibulk reply
    elseif prefix == '*' then
        local count = tonumber(data)

        if count == -1 then
            return nil
        end

        local list = {}
        if count > 0 then
            local reader = response.read
            for i = 1, count do
                list[i] = reader(client)
            end
        end
        return list

   -- unknown type of reply
    else
        return client.error('unknown response prefix: ' .. prefix)
    end
end

-- ############################################################################

function request.raw(client, buffer)
    local bufferType = type(buffer)

    if bufferType == 'table' then
        client.network.write(client, table.concat(buffer))
    elseif bufferType == 'string' then
        client.network.write(client, buffer)
    else
        client.error('argument error: ' .. bufferType)
    end
end

function request.multibulk(client, command, ...)
    local args = {...}
    local argsn = #args
    local buffer = { true, true }

    if argsn == 1 and type(args[1]) == 'table' then
        argsn, args = #args[1], args[1]
    end

    buffer[1] = '*' .. tostring(argsn + 1) .. "\r\n"
    buffer[2] = '$' .. #command .. "\r\n" .. command .. "\r\n"

    local table_insert = table.insert
    for i = 1, argsn do
        local s_argument = tostring(args[i] or '')
        table_insert(buffer, '$' .. #s_argument .. "\r\n" .. s_argument .. "\r\n")
    end

    client.network.write(client, table.concat(buffer))
end

-- ############################################################################

local function custom(command, send, parse)
    command = string.upper(command)
    return function(client, ...)
        send(client, command, ...)
        local reply, err = response.read(client)

        if type(reply) == 'table' and reply.queued then
            reply.parser = parse
            return reply
        elseif reply == nil then
            return reply, err
        else
            if parse then
                return parse(reply, command, ...)
            end
            return reply
        end
    end
end

local function command(command, opts)
    if opts == nil or type(opts) == 'function' then
        return custom(command, request.multibulk, opts)
    else
        return custom(command, opts.request or request.multibulk, opts.response)
    end
end

local define_command_impl = function(target, name, opts)
    local opts = opts or {}
    target[string.lower(name)] = custom(
        opts.command or string.upper(name),
        opts.request or request.multibulk,
        opts.response or nil
    )
end

local undefine_command_impl = function(target, name)
    target[string.lower(name)] = nil
end

-- ############################################################################

local client_prototype = {}

client_prototype.raw_cmd = function(client, buffer)
    request.raw(client, buffer .. "\r\n")
    return response.read(client)
end

-- obsolete
client_prototype.define_command = function(client, name, opts)
    define_command_impl(client, name, opts)
end

-- obsolete
client_prototype.undefine_command = function(client, name)
    undefine_command_impl(client, name)
end

client_prototype.quit = function(client)
    request.multibulk(client, 'QUIT')
    client.network.socket:shutdown()
    return true
end

client_prototype.shutdown = function(client)
    request.multibulk(client, 'SHUTDOWN')
    client.network.socket:shutdown()
end

-- Command pipelining

client_prototype.pipeline = function(client, block)
    local requests, replies, parsers = {}, {}, {}
    local table_insert = table.insert
    local socket_write, socket_read = client.network.write, client.network.read

    client.network.write = function(_, buffer)
        table_insert(requests, buffer)
    end

    -- TODO: this hack is necessary to temporarily reuse the current
    --       request -> response handling implementation of redis-lua
    --       without further changes in the code, but it will surely
    --       disappear when the new command-definition infrastructure
    --       will finally be in place.
    client.network.read = function() return '+QUEUED' end

    local pipeline = setmetatable({}, {
        __index = function(env, name)
            local cmd = client[name]
            if not cmd then
                client.error('unknown redis command: ' .. name, 2)
            end
            return function(self, ...)
                local reply = cmd(client, ...)
                table_insert(parsers, #requests, reply.parser)
                return reply
            end
        end
    })

    local success, retval = pcall(block, pipeline)

    client.network.write, client.network.read = socket_write, socket_read
    if not success then return client.error(retval, 0) end

    client.network.write(client, table.concat(requests, ''))

    for i = 1, #requests do
        local reply, parser = response.read(client), parsers[i]
        if parser then
            reply = parser(reply)
        end
        table_insert(replies, i, reply)
    end

    return replies, #requests
end

-- Publish/Subscribe

do
    local channels = function(channels)
        if type(channels) == 'string' then
            channels = { channels }
        end
        return channels
    end

    local subscribe = function(client, ...)
        request.multibulk(client, 'subscribe', ...)
    end
    local psubscribe = function(client, ...)
        request.multibulk(client, 'psubscribe', ...)
    end
    local unsubscribe = function(client, ...)
        request.multibulk(client, 'unsubscribe')
    end
    local punsubscribe = function(client, ...)
        request.multibulk(client, 'punsubscribe')
    end

    local consumer_loop = function(client)
        local aborting, subscriptions = false, 0

        local abort = function()
            if not aborting then
                unsubscribe(client)
                punsubscribe(client)
                aborting = true
            end
        end

        return coroutine.wrap(function()
            while true do
                local message
                local response = response.read(client)

                if response[1] == 'pmessage' then
                    message = {
                        kind    = response[1],
                        pattern = response[2],
                        channel = response[3],
                        payload = response[4],
                    }
                else
                    message = {
                        kind    = response[1],
                        channel = response[2],
                        payload = response[3],
                    }
                end

                if string.match(message.kind, '^p?subscribe$') then
                    subscriptions = subscriptions + 1
                end
                if string.match(message.kind, '^p?unsubscribe$') then
                    subscriptions = subscriptions - 1
                end

                if aborting and subscriptions == 0 then
                    break
                end
                coroutine.yield(message, abort)
            end
        end)
    end

    client_prototype.pubsub = function(client, subscriptions)
        if type(subscriptions) == 'table' then
            if subscriptions.subscribe then
                subscribe(client, channels(subscriptions.subscribe))
            end
            if subscriptions.psubscribe then
                psubscribe(client, channels(subscriptions.psubscribe))
            end
        end
        return consumer_loop(client)
    end
end

-- Redis transactions (MULTI/EXEC)

do
    local function identity(...) return ... end
    local emptytable = {}

    local function initialize_transaction(client, options, block, queued_parsers)
        local table_insert = table.insert
        local coro = coroutine.create(block)

        if options.watch then
            local watch_keys = {}
            for _, key in pairs(options.watch) do
                table_insert(watch_keys, key)
            end
            if #watch_keys > 0 then
                client:watch(unpack(watch_keys))
            end
        end

        local transaction_client = setmetatable({}, {__index=client})
        transaction_client.exec  = function(...)
            return client.error('cannot use EXEC inside a transaction block')
        end
        transaction_client.multi = function(...)
            coroutine.yield()
        end
        transaction_client.commands_queued = function()
            return #queued_parsers
        end

        assert(coroutine.resume(coro, transaction_client))

        transaction_client.multi = nil
        transaction_client.discard = function(...)
            local reply = client:discard()
            for i, v in pairs(queued_parsers) do
                queued_parsers[i]=nil
            end
            coro = initialize_transaction(client, options, block, queued_parsers)
            return reply
        end
        transaction_client.watch = function(...)
            return client.error('WATCH inside MULTI is not allowed')
        end
        setmetatable(transaction_client, { __index = function(t, k)
                local cmd = client[k]
                if type(cmd) == "function" then
                    local function queuey(self, ...)
                        local reply = cmd(client, ...)
                        assert((reply or emptytable).queued == true, 'a QUEUED reply was expected')
                        table_insert(queued_parsers, reply.parser or identity)
                        return reply
                    end
                    t[k]=queuey
                    return queuey
                else
                    return cmd
                end
            end
        })
        client:multi()
        return coro
    end

    local function transaction(client, options, coroutine_block, attempts)
        local queued_parsers, replies = {}, {}
        local retry = tonumber(attempts) or tonumber(options.retry) or 2
        local coro = initialize_transaction(client, options, coroutine_block, queued_parsers)

        local success, retval
        if coroutine.status(coro) == 'suspended' then
            success, retval = coroutine.resume(coro)
        else
            -- do not fail if the coroutine has not been resumed (missing t:multi() with CAS)
            success, retval = true, 'empty transaction'
        end
        if #queued_parsers == 0 or not success then
            client:discard()
            assert(success, retval)
            return replies, 0
        end

        local raw_replies = client:exec()
        if not raw_replies then
            if (retry or 0) <= 0 then
                return client.error("MULTI/EXEC transaction aborted by the server")
            else
                --we're not quite done yet
                return transaction(client, options, coroutine_block, retry - 1)
            end
        end

        local table_insert = table.insert
        for i, parser in pairs(queued_parsers) do
            table_insert(replies, i, parser(raw_replies[i]))
        end

        return replies, #queued_parsers
    end

    client_prototype.transaction = function(client, arg1, arg2)
        local options, block
        if not arg2 then
            options, block = {}, arg1
        elseif arg1 then --and arg2, implicitly
            options, block = type(arg1)=="table" and arg1 or { arg1 }, arg2
        else
            return client.error("Invalid parameters for redis transaction.")
        end

        if not options.watch then
            local watch_keys = { }
            for i, v in pairs(options) do
                if tonumber(i) then
                    table.insert(watch_keys, v)
                    options[i] = nil
                end
            end
            options.watch = watch_keys
        elseif not (type(options.watch) == 'table') then
            options.watch = { options.watch }
        end

        if not options.cas then
            local tx_block = block
            block = function(client, ...)
                client:multi()
                return tx_block(client, ...) --can't wrap this in pcall because we're in a coroutine.
            end
        end

        return transaction(client, options, block)
    end
end

-- MONITOR context

do
    local monitor_loop = function(client)
        local monitoring = true

        -- Tricky since the payload format changed starting from Redis 2.6.
        local pattern = '^(%d+%.%d+)( ?.- ?) ?"(%a+)" ?(.-)$'

        local abort = function()
            monitoring = false
        end

        return coroutine.wrap(function()
            client:monitor()

            while monitoring do
                local message, matched
                local response = response.read(client)

                local ok = response:gsub(pattern, function(time, info, cmd, args)
                    message = {
                        timestamp = tonumber(time),
                        client    = info:match('%d+.%d+.%d+.%d+:%d+'),
                        database  = tonumber(info:match('%d+')) or 0,
                        command   = cmd,
                        arguments = args:match('.+'),
                    }
                    matched = true
                end)

                if not matched then
                    return client.error('Unable to match MONITOR payload: '..response)
                end

                coroutine.yield(message, abort)
            end
        end)
    end

    client_prototype.monitor_messages = function(client)
        return monitor_loop(client)
    end
end

-- ############################################################################

local function connect_tcp(socket, parameters)
    local host, port = parameters.host, tonumber(parameters.port)
    if parameters.timeout then
        socket:settimeout(parameters.timeout, 'b')
    end

    local ok, err = socket:connect(host, port)
    if not ok then
        redis.error('could not connect to '..host..':'..port..' ['..err..']')
    end
    socket:setoption('tcp-nodelay', parameters.tcp_nodelay)
    return socket
end

local function connect_unix(socket, parameters)
    local ok, err = socket:connect(parameters.path)
    if not ok then
        redis.error('could not connect to '..parameters.path..' ['..err..']')
    end
    return socket
end

local function create_connection(parameters)
    if parameters.socket then
        return parameters.socket
    end

    local perform_connection, socket

    if parameters.scheme == 'unix' then
        perform_connection, socket = connect_unix, require('socket.unix')
        assert(socket, 'your build of LuaSocket does not support UNIX domain sockets')
    else
        if parameters.scheme then
            local scheme = parameters.scheme
            assert(scheme == 'redis' or scheme == 'tcp', 'invalid scheme: '..scheme)
        end
        perform_connection, socket = connect_tcp, require('socket').tcp
    end

    return perform_connection(socket(), parameters)
end

-- ############################################################################

function redis.error(message, level)
    error(message, (level or 1) + 1)
end

function redis.connect(...)
    local args, parameters = {...}, nil

    if #args == 1 then
        if type(args[1]) == 'table' then
            parameters = args[1]
        else
            local uri = require('socket.url')
            parameters = uri.parse(select(1, ...))
            if parameters.scheme then
                if parameters.query then
                    for k, v in parameters.query:gmatch('([-_%w]+)=([-_%w]+)') do
                        if k == 'tcp_nodelay' or k == 'tcp-nodelay' then
                            parameters.tcp_nodelay = parse_boolean(v)
                        elseif k == 'timeout' then
                            parameters.timeout = tonumber(v)
                        end
                    end
                end
            else
                parameters.host = parameters.path
            end
        end
    elseif #args > 1 then
        local host, port, timeout = unpack(args)
        parameters = { host = host, port = port, timeout = tonumber(timeout) }
    end

    local commands = redis.commands or {}
    if type(commands) ~= 'table' then
        redis.error('invalid type for the commands table')
    end

    local socket = create_connection(merge_defaults(parameters))
    local client = create_client(client_prototype, socket, commands)

    return client
end

function redis.command(cmd, opts)
    return command(cmd, opts)
end

-- obsolete
function redis.define_command(name, opts)
    define_command_impl(redis.commands, name, opts)
end

-- obsolete
function redis.undefine_command(name)
    undefine_command_impl(redis.commands, name)
end

-- ############################################################################

-- Commands defined in this table do not take the precedence over
-- methods defined in the client prototype table.

redis.commands = {
    -- commands operating on the key space
    exists           = command('EXISTS', {
        response = toboolean
    }),
    del              = command('DEL'),
    type             = command('TYPE'),
    rename           = command('RENAME'),
    renamenx         = command('RENAMENX', {
        response = toboolean
    }),
    expire           = command('EXPIRE', {
        response = toboolean
    }),
    pexpire          = command('PEXPIRE', {     -- >= 2.6
        response = toboolean
    }),
    expireat         = command('EXPIREAT', {
        response = toboolean
    }),
    pexpireat        = command('PEXPIREAT', {   -- >= 2.6
        response = toboolean
    }),
    ttl              = command('TTL'),
    pttl             = command('PTTL'),         -- >= 2.6
    move             = command('MOVE', {
        response = toboolean
    }),
    dbsize           = command('DBSIZE'),
    persist          = command('PERSIST', {     -- >= 2.2
        response = toboolean
    }),
    keys             = command('KEYS', {
        response = function(response)
            if type(response) == 'string' then
                -- backwards compatibility path for Redis < 2.0
                local keys = {}
                response:gsub('[^%s]+', function(key)
                    table.insert(keys, key)
                end)
                response = keys
            end
            return response
        end
    }),
    randomkey        = command('RANDOMKEY'),
    sort             = command('SORT', {
        request = sort_request,
    }),
    scan             = command('SCAN', {        -- >= 2.8
        request = scan_request,
    }),

    -- commands operating on string values
    set              = command('SET'),
    setnx            = command('SETNX', {
        response = toboolean
    }),
    setex            = command('SETEX'),        -- >= 2.0
    psetex           = command('PSETEX'),       -- >= 2.6
    mset             = command('MSET', {
        request = mset_filter_args
    }),
    msetnx           = command('MSETNX', {
        request  = mset_filter_args,
        response = toboolean
    }),
    get              = command('GET'),
    mget             = command('MGET'),
    getset           = command('GETSET'),
    incr             = command('INCR'),
    incrby           = command('INCRBY'),
    incrbyfloat      = command('INCRBYFLOAT', { -- >= 2.6
        response = function(reply, command, ...)
            return tonumber(reply)
        end,
    }),
    decr             = command('DECR'),
    decrby           = command('DECRBY'),
    append           = command('APPEND'),       -- >= 2.0
    substr           = command('SUBSTR'),       -- >= 2.0
    strlen           = command('STRLEN'),       -- >= 2.2
    setrange         = command('SETRANGE'),     -- >= 2.2
    getrange         = command('GETRANGE'),     -- >= 2.2
    setbit           = command('SETBIT'),       -- >= 2.2
    getbit           = command('GETBIT'),       -- >= 2.2
    bitop            = command('BITOP'),        -- >= 2.6
    bitcount         = command('BITCOUNT'),     -- >= 2.6

    -- commands operating on lists
    rpush            = command('RPUSH'),
    lpush            = command('LPUSH'),
    llen             = command('LLEN'),
    lrange           = command('LRANGE'),
    ltrim            = command('LTRIM'),
    lindex           = command('LINDEX'),
    lset             = command('LSET'),
    lrem             = command('LREM'),
    lpop             = command('LPOP'),
    rpop             = command('RPOP'),
    rpoplpush        = command('RPOPLPUSH'),
    blpop            = command('BLPOP'),        -- >= 2.0
    brpop            = command('BRPOP'),        -- >= 2.0
    rpushx           = command('RPUSHX'),       -- >= 2.2
    lpushx           = command('LPUSHX'),       -- >= 2.2
    linsert          = command('LINSERT'),      -- >= 2.2
    brpoplpush       = command('BRPOPLPUSH'),   -- >= 2.2

    -- commands operating on sets
    sadd             = command('SADD'),
    srem             = command('SREM'),
    spop             = command('SPOP'),
    smove            = command('SMOVE', {
        response = toboolean
    }),
    scard            = command('SCARD'),
    sismember        = command('SISMEMBER', {
        response = toboolean
    }),
    sinter           = command('SINTER'),
    sinterstore      = command('SINTERSTORE'),
    sunion           = command('SUNION'),
    sunionstore      = command('SUNIONSTORE'),
    sdiff            = command('SDIFF'),
    sdiffstore       = command('SDIFFSTORE'),
    smembers         = command('SMEMBERS'),
    srandmember      = command('SRANDMEMBER'),
    sscan            = command('SSCAN', {       -- >= 2.8
        request = scan_request,
    }),

    -- commands operating on sorted sets
    zadd             = command('ZADD'),
    zincrby          = command('ZINCRBY', {
        response = function(reply, command, ...)
            return tonumber(reply)
        end,
    }),
    zrem             = command('ZREM'),
    zrange           = command('ZRANGE', {
        request  = zset_range_request,
        response = zset_range_reply,
    }),
    zrevrange        = command('ZREVRANGE', {
        request  = zset_range_request,
        response = zset_range_reply,
    }),
    zrangebyscore    = command('ZRANGEBYSCORE', {
        request  = zset_range_byscore_request,
        response = zset_range_reply,
    }),
    zrevrangebyscore = command('ZREVRANGEBYSCORE', {    -- >= 2.2
        request  = zset_range_byscore_request,
        response = zset_range_reply,
    }),
    zunionstore      = command('ZUNIONSTORE', {         -- >= 2.0
        request = zset_store_request
    }),
    zinterstore      = command('ZINTERSTORE', {         -- >= 2.0
        request = zset_store_request
    }),
    zcount           = command('ZCOUNT'),
    zcard            = command('ZCARD'),
    zscore           = command('ZSCORE'),
    zremrangebyscore = command('ZREMRANGEBYSCORE'),
    zrank            = command('ZRANK'),                -- >= 2.0
    zrevrank         = command('ZREVRANK'),             -- >= 2.0
    zremrangebyrank  = command('ZREMRANGEBYRANK'),      -- >= 2.0
    zscan            = command('ZSCAN', {               -- >= 2.8
        request  = scan_request,
        response = zscan_response,
    }),

    -- commands operating on hashes
    hset             = command('HSET', {        -- >= 2.0
        response = toboolean
    }),
    hsetnx           = command('HSETNX', {      -- >= 2.0
        response = toboolean
    }),
    hmset            = command('HMSET', {       -- >= 2.0
        request  = hash_multi_request_builder(function(args, k, v)
            table.insert(args, k)
            table.insert(args, v)
        end),
    }),
    hincrby          = command('HINCRBY'),      -- >= 2.0
    hincrbyfloat     = command('HINCRBYFLOAT', {-- >= 2.6
        response = function(reply, command, ...)
            return tonumber(reply)
        end,
    }),
    hget             = command('HGET'),         -- >= 2.0
    hmget            = command('HMGET', {       -- >= 2.0
        request  = hash_multi_request_builder(function(args, k, v)
            table.insert(args, v)
        end),
    }),
    hdel             = command('HDEL'),        -- >= 2.0
    hexists          = command('HEXISTS', {     -- >= 2.0
        response = toboolean
    }),
    hlen             = command('HLEN'),         -- >= 2.0
    hkeys            = command('HKEYS'),        -- >= 2.0
    hvals            = command('HVALS'),        -- >= 2.0
    hgetall          = command('HGETALL', {     -- >= 2.0
        response = function(reply, command, ...)
            local new_reply = { }
            for i = 1, #reply, 2 do new_reply[reply[i]] = reply[i + 1] end
            return new_reply
        end
    }),
    hscan            = command('HSCAN', {       -- >= 2.8
        request  = scan_request,
        response = hscan_response,
    }),

    -- connection related commands
    ping             = command('PING', {
        response = function(response) return response == 'PONG' end
    }),
    echo             = command('ECHO'),
    auth             = command('AUTH'),
    select           = command('SELECT'),

    -- transactions
    multi            = command('MULTI'),        -- >= 2.0
    exec             = command('EXEC'),         -- >= 2.0
    discard          = command('DISCARD'),      -- >= 2.0
    watch            = command('WATCH'),        -- >= 2.2
    unwatch          = command('UNWATCH'),      -- >= 2.2

    -- publish - subscribe
    subscribe        = command('SUBSCRIBE'),    -- >= 2.0
    unsubscribe      = command('UNSUBSCRIBE'),  -- >= 2.0
    psubscribe       = command('PSUBSCRIBE'),   -- >= 2.0
    punsubscribe     = command('PUNSUBSCRIBE'), -- >= 2.0
    publish          = command('PUBLISH'),      -- >= 2.0

    -- redis scripting
    eval             = command('EVAL'),         -- >= 2.6
    evalsha          = command('EVALSHA'),      -- >= 2.6
    script           = command('SCRIPT'),       -- >= 2.6

    -- remote server control commands
    bgrewriteaof     = command('BGREWRITEAOF'),
    config           = command('CONFIG', {     -- >= 2.0
        response = function(reply, command, ...)
            if (type(reply) == 'table') then
                local new_reply = { }
                for i = 1, #reply, 2 do new_reply[reply[i]] = reply[i + 1] end
                return new_reply
            end

            return reply
        end
    }),
    client           = command('CLIENT'),       -- >= 2.4
    slaveof          = command('SLAVEOF'),
    save             = command('SAVE'),
    bgsave           = command('BGSAVE'),
    lastsave         = command('LASTSAVE'),
    flushdb          = command('FLUSHDB'),
    flushall         = command('FLUSHALL'),
    monitor          = command('MONITOR'),
    time             = command('TIME'),         -- >= 2.6
    slowlog          = command('SLOWLOG', {     -- >= 2.2.13
        response = function(reply, command, ...)
            if (type(reply) == 'table') then
                local structured = { }
                for index, entry in ipairs(reply) do
                    structured[index] = {
                        id = tonumber(entry[1]),
                        timestamp = tonumber(entry[2]),
                        duration = tonumber(entry[3]),
                        command = entry[4],
                    }
                end
                return structured
            end

            return reply
        end
    }),
    info             = command('INFO', {
        response = parse_info,
    }),
}

-- ############################################################################

return redis -- redis-lua module end -------------------------------------------
end)()

local api = {
  KEYS = {
    type = "value",
    description = "A table with the key names that were explicitly declared for the script to access."
  },
  ARGV = {
    type = "value",
    description = "A table with the arguments that were passed to the script."
  },

  redis = {
    type = "lib",
    description = "A library for inteacting with the Redis server in which the script is EVALed.",
    childs = {

      -- Values
      REPL_ALL = {
        type = "value",
        description = "Target setting for calling redis.set_repl() that replicates effects both to AOF and slaves (the default).",
      },
      REPL_AOF  = {
        type = "value",
        description = "Target setting for calling redis.set_repl() that replicates effects only to AOF.",
      },
      REPL_SLAVE = {
        type = "value",
        description = "Target setting for calling redis.set_repl() that replicates effects only to slaves.",
      },
      REPL_NONE = {
        type = "value",
        description = "Target setting for calling redis.set_repl() that disables replication.",
      },

      LOG_DEBUG = {
        type = "value",
        description = "DEBUG loglevel setting for calling redis.log().",
      },
      LOG_VERBOSE = {
        type = "value",
        description = "VERBOSE loglevel setting for calling redis.log().",
      },
      LOG_NOTICE = {
        type = "value",
        description = "NOTICE loglevel setting for calling redis.log().",
      },
      LOG_WARNING = {
        type = "value",
        description = "WARNING loglevel setting for calling redis.log().",
      },

      -- functions
      error_reply = {
        type = "function",
        description = "Returns a Redis error reply.\nThis helper function returns a single field table with the err field set to the specified string.",
        args = "(error: string)",
        returns = "(table)",
      },

      status_reply = {
        type = "function",
        description = "Returns a Redis status reply.\nThis helper function returns a single field table with the ok field set to the specified string.",
        args = "(status: string)",
        returns = "(table)",
      },

      call = {
        type = "function",
        description = "Calls a Redis command, raising errors if any.\nIf the call to the command returns an error, the error will be raised and returned to the caller. To trap the error consider using pcall instead.\nThe arguments should be a well-formed Redis command. The return value depends on the command called and the dataset.",
        args = "(command: string, [arg: string|number, ...])",
        returns = "(number|string|table|boolean)",
      },

      pcall = {
        type = "function",
        description = "Calls a Redis command, trapping errors if any.\nIf the call to the command returns an error, the error will be trapped and the function will return a table with the error. To raise the error to the caller consider using call instead.\nThe arguments should be a well-formed Redis command. The return value depends on the command called and the dataset.",
        args = "(command: string, [arg: string|number, ...])",
        returns = "(number|string|table|boolean)",
      },

      replicate_commands = {
        type = "function",
        description = "Enables effects replication mode for the script.\nReturns true if successful.\n",
        args = "()",
        returns = "(boolean)",
      },

      set_repl = {
        type = "function",
        description = "Sets the replication target when in effects replication mode.\n\nAccepts one of the following targets:\n* redis.REPL_ALL: Replicate to AOF and slaves (the default).\n* redis.REPL_AOF: Replicate only to AOF.\n* redis.REPL_SLAVE: Replicate only to slaves.\n* redis.REPL_NONE: Don't replicate at all.",
        args = "(target: redis.REPL_(ALL|AOF|SLAVE|NONE))", -- TODO: replace with something else?
        returns = "()",
      },

      sha1hex = {
        type = "function",
        description = "Performs the SHA1 of the input string.",
        args = "(input: string)",
        returns = "(string)",
      },

      breakpoint = {
        type = "function",
        description = "When in SCRIPT DEBUG mode, stops execution as if a breakpoint is encountered at the next line.",
        args = "()",
        returns = "()",
      },

      debug = {
        type = "function",
        description = "When in SCRIPT DEBUG mode, emits a log message to the debug console.",
        args = "(message: string)",
        returns = "()",
      },

      log = {
        type = "function",
        description = "Emits a log message to the Redis log file.\nAccepst one of the standard Redis loglevels and the message to emit.",
        args = "(loglevel: redis.LOG_(DEBUG|VERBOSE|NOTICE|WARNING), message: string)",
        returns = "()",
      },

    },
  },

  struct = {
    type = "lib",
    description = "A library for packing/unpacking structures within Lua.",
    childs = {
      pack = {
        type = "function",
        description = "Returns an encoded representation of the arguments according to the specified format.\n\nValid formats:\n> - big endian\n< - little endian\n![num] - alignment\nx - padding\nb/B - signed/unsigned byte\nh/H - signed/unsigned short\nl/L - signed/unsigned long\nT   - size_t\ni/In - signed/unsigned integer with size `n' (default is size of int)\ncn - sequence of `n' chars (from/to a string); when packing, n==0 means\n     the whole string; when unpacking, n==0 means use the previous\n     read number as the string length\ns - zero-terminated string\nf - float\nd - double\n' ' - ignored",
        args = "(format: string, ...)",
        returns = "(string)",
      },
      unpack = {
        type = "function",
        description = "Returns the values from an encoded representation according to the specified format.\n\nValid formats:\n> - big endian\n< - little endian\n![num] - alignment\nx - padding\nb/B - signed/unsigned byte\nh/H - signed/unsigned short\nl/L - signed/unsigned long\nT   - size_t\ni/In - signed/unsigned integer with size `n' (default is size of int)\ncn - sequence of `n' chars (from/to a string); when packing, n==0 means\n     the whole string; when unpacking, n==0 means use the previous\n     read number as the string length\ns - zero-terminated string\nf - float\nd - double\n' ' - ignored",
        args = "(format: string, struct: string)",
        returns = "(table)", -- TODO: the table also has an additional element???
      },
      size = {
        type = "function",
        description = "Returns the size of the encoded representation according to the specified format.\n\nValid formats:\n> - big endian\n< - little endian\n![num] - alignment\nx - padding\nb/B - signed/unsigned byte\nh/H - signed/unsigned short\nl/L - signed/unsigned long\nT   - size_t\ni/In - signed/unsigned integer with size `n' (default is size of int)\ncn - sequence of `n' chars (from/to a string); when packing, n==0 means\n     the whole string; when unpacking, n==0 means use the previous\n     read number as the string length\ns - zero-terminated string\nf - float\nd - double\n' ' - ignored",
        args = "(format: string)",
        returns = "(number)"
      },
    },
  },

  cjson = {
    type = "lib",
    description = "A library for encoding/decoding JSON.",
    childs = {
      encode = {
        type = "function",
        description = "Encodes a Lua table as a JSON document.",
        args = "(input: table)",
        returns = "(string)",
      },
      decode = {
        type = "function",
        description = "Converts a JSON document to a Lua table.",
        args = "(JSON: string)",
        returns = "(table)",
      },
    },
  },

  cmsgpack = {
    type = "lib",
    description = "A library for encoding/decoding MessagePack.",
    childs = {
      pack = {
        type = "function",
        description = "Encodes a Lua table as a MessagePack.",
        args = "(input: table)",
        returns = "(string)",
      },
      unpack = {
        type = "function",
        description = "Converts a MessagePack to a Lua table.",
        args = "(msgpack: string)",
        returns = "(table)",
      },
    },
  },

  bit = {
    type = "lib",
    description = "A library for bitwise operations on numbers.",
    childs = {
      tobit = {
        type = "function",
        description = "Normalizes a number to the numeric range for bit operations and returns it.",
        args = "(x: number)",
        returns = "(number)",
      },
      tohex = {
        type = "function",
        description = "Converts its first argument to a hex string. The number of hex digits is given by the absolute value of the optional second argument. Positive numbers between 1 and 8 generate lowercase hex digits. Negative numbers generate uppercase hex digits. Only the least-significant 4*|n| bits are used. The default is to generate 8 lowercase hex digits.",
        args = "(x: number [, n: number])",
        returns = "(string)",
      },
      bnot = {
        type = "function",
        description = "Returns the bitwise not of its argument.",
        args = "(x: number)",
        returns = "(number)",
      },
      band = {
        type = "function",
        description = "Returns the bitwise and of all of its arguments.",
        args = "(x1: number [, x2: number, ...])",
        returns = "(number)",
      },
      bor = {
        type = "function",
        description = "Returns the bitwise or of all of its arguments.",
        args = "(x1: number [, x2: number, ...])",
        returns = "(number)",
      },
      bxor = {
        type = "function",
        description = "Returns the bitwise xor of all of its arguments.",
        args = "(x1: number [, x2: number, ...])",
        returns = "(number)",
      },
      lshift = {
        type = "function",
        description = "Returns the bitwise logical left-shift of its first argument by the number of bits given by the second argument.\nTreats the first argument as an unsigned number and shifts in 0-bits.\nOnly the lower 5 bits of the shift count are used (reduces to the range [0..31]).",
        args = "(x: number, n: number)",
        returns = "(number)",
      },
      rshift = {
        type = "function",
        description = "Returns the bitwise logical right-shift of its first argument by the number of bits given by the second argument.\nTreats the first argument as an unsigned number and shifts in 0-bits.\nOnly the lower 5 bits of the shift count are used (reduces to the range [0..31]).",
        args = "(x: number, n: number)",
        returns = "(number)",
      },
      arshift = {
        type = "function",
        description = "Returns the bitwise arithmetic right-shift of its first argument by the number of bits given by the second argument.\nTreats the most-significant bit as a sign bit and replicates it.\nOnly the lower 5 bits of the shift count are used (reduces to the range [0..31]).",
        args = "(x: number, n: number)",
        returns = "(number)",
      },
      rol = {
        type = "function",
        description = "Returns the bitwise left rotation of its first argument by the number of bits given by the second argument.\nBits shifted out on one side are shifted back in on the other side.\nOnly the lower 5 bits of the rotate count are used (reduces to the range [0..31]).",
        args = "(x: number, n: number)",
        returns = "(number)",
      },
      ror = {
        type = "function",
        description = "Returns the bitwise right rotation of its first argument by the number of bits given by the second argument.\nBits shifted out on one side are shifted back in on the other side.\nOnly the lower 5 bits of the rotate count are used (reduces to the range [0..31]).",
        args = "(x: number, n: number)",
        returns = "(number)",
      },
      bswap = {
        type = "function",
        description = "Swaps the bytes of its argument and returns it.",
        args = "(x: number)",
        returns = "(number)",
      },
    },
  },
}

local function isinstance(host, port, password)
  local ok, res = pcall(redis.connect, {host = host, port = port, timeout = 0.5})
  if not ok then return nil, res:match('%[.+%]') end

  -- check if the instance is password protected
  local client = res
  ok, res = pcall(client.ping, client)
  if not ok and res:find("NOAUTH")
  and (not password or not pcall(client.auth, client, password)) then
    while true do
      password = password or wx.wxGetTextFromUser("Enter Redis password", "Redis authentication")
      if not password or password == "" then return end
      if pcall(client.auth, client, password) then break end
      password = nil
    end
  end

  client:quit()
  return true, password
end

local pkg
local address, password
local interpreter = {
  name = "Redis",
  description = "Redis interpreter",
  api = {"baselib", "redis"},
  frun = function(self,wfilename,rundebug)
    if not pkg then
      DisplayOutputLn("Can't get package configuration.")
      return
    end
    local filepath = wfilename:GetFullPath()
    if ide.osname == 'Windows' then
      -- if running on Windows and can't open the file, this may mean that
      -- the file path includes unicode characters that need special handling
      local fh = io.open(filepath, "r")
      if fh then fh:close() end
      if pcall(require, "winapi") and wfilename:FileExists() and not fh then
        winapi.set_encoding(winapi.CP_UTF8)
        filepath = winapi.short_path(filepath)
      end
    end
    local defaddress = pkg:GetSettings().address or "localhost:6379"
    while true do
      defaddress = address or wx.wxGetTextFromUser(
        "Enter Redis instance address (host:port)", "Redis configuration", defaddress)
      if not defaddress or defaddress == "" then return end
      local host, port = defaddress:match("^%s*(.+):(%d+)%s*$")
      if not host or not port then
        DisplayOutputLn(("Can't get host name and port number from address '%s'."):format(defaddress))
      else
        local ok, err = isinstance(host, port, password)
        if ok then
          address, password = defaddress, err
          pkg:SetSettings({address = address})
          break
        elseif err then
          DisplayOutputLn(("Can't connect to address '%s': %s."):format(defaddress, err))
          address = nil
        else -- cancelled authentication
          return
        end
      end
    end

    if rundebug then DebuggerAttachDefault() end
    local redis = " --instance "..address
    local controller = " --controller "..ide:GetDebugger():GetHostName()..":"..ide:GetDebugger():GetPortNumber()
    local rundebug = " --debug " .. (rundebug and (pkg:GetConfig().debugmode or "yes") or "no")
    local pswd = password and (' --password %q'):format(password) or ""
    local cfg = ide:GetConfig()
    local params = cfg.arg.any or cfg.arg.redis
    local exe = ide:GetInterpreters().luadeb:GetExePath("")
    local cmd = ('"%s" "%s"%s%s%s%s "%s"%s'):format(
      exe, pkg:GetFilePath(), redis, controller, rundebug, pswd, filepath, params and " "..params or "")

    -- CommandLineRun(cmd,wdir,tooutput,nohide,stringcallback,uid,endcallback)
    return CommandLineRun(cmd,self:fworkdir(wfilename),true,false)
  end,
  hasdebugger = true,
  fattachdebug = function(self) DebuggerAttachDefault() end,
  unhideanywindow = false,
  takeparameters = true,
}

local name = "redis"
local package = {
  name = "Redis",
  description = "Integrates with Redis.",
  author = "Paul Kulchenko",
  version = 0.13,
  dependencies = 1.21,

  onRegister = function(self)
    pkg = self
    ide:AddInterpreter(name, interpreter)
    ide:AddAPI("lua", name, api)
  end,
  onUnRegister = function(self)
    ide:RemoveInterpreter(name)
    ide:RemoveAPI("lua", name)
  end,
}

if pcall(debug.getlocal, 4, 1) then return package end

-- main redis script -----------------------------------------------------------

io.stdout:setvbuf('no')

local unpack = unpack or table.unpack
local controller, instance = "localhost:8172", "localhost:6379"
local rundebug, password, params, file
while #arg > 0 do
  local a = table.remove(arg, 1)
  if a == "--instance" then
    instance = table.remove(arg, 1)
  elseif a == "--controller" then
    controller = table.remove(arg, 1)
  elseif a == "--debug" then
    rundebug = table.remove(arg, 1)
  elseif a == "--password" then
    password = table.remove(arg, 1)
  else
    file, params, arg = a, arg, {}
  end
end

local function check(cond, msg, ...)
  if cond or msg == nil then return cond, msg, ... end
  print(msg)
  os.exit(1)
end

check(file, "Required file name is not provided")

-- read the script
local fh, err = io.open(file, "rb")
check(fh, ("Can't open file '%s' for reading: %s"):format(file, err))
local code = fh:read("*a")
fh:close()

local function getline(response) return type(response) == 'table' and response[1] and response[1]:match("* Stopped at (%d+)") end
local function getval(response, keyword, format)
  if type(response) ~= 'table' then return end
  local res = {}
  for _, v in ipairs(response) do
    if v:find("^"..keyword) then
      table.insert(res, (format or "%q"):format(v:gsub(keyword.." ","")))
    end
  end
  return res
end
local function getretval(response)
  return "return {"..table.concat(getval(response, "<retval>"), ",").."}"
end
local function getreply(response)
  return "return {"..table.concat(getval(response, "<reply>", "%s"), ",").."}"
end
local function geterror(response)
  local err = getval(type(response) == 'table' and response or {response}, "<error>")
  return err and #err > 0 and err[1] or nil
end
local function isdone(response) return #getval(response, "<endsession>") > 0 end
local function isfilesame(fullname, fname, basedir)
  local sep = "/"
  fullname = fullname:gsub("[\\/]", sep)
  basedir = basedir:gsub("[\\/]", sep):gsub(sep.."+$", "")..sep
  return fullname == fname or fullname == basedir .. fname
end
local function getlocals(response)
  if type(response) ~= 'table' then return end
  -- convert reported values to local definitions; skip internal variables
  -- <value> (for index) = 1
  -- <value> (for limit) = 20
  -- <value> i = 1
  local res = {}
  for _, v in ipairs(response) do
    if not v:find("<value> %(") then
      local val = v:gsub("<value>", "local")
      if loadstring(val) then table.insert(res, val) end
    end
  end
  return table.concat(res, ";").."; "
end

-- get redis instance host:port
local host, port = instance:match("^%s*(.+):(%d+)%s*$")
check(host and port, ("Unknown Redis instance address format '%s'; expected host:port."):format(instance))

-- register Redis debugger commands
redis.commands.ldbcontinue = redis.command('C')
redis.commands.ldbstep = redis.command('S')
redis.commands.ldbbreakpoint = redis.command('B')
redis.commands.ldbabort = redis.command('A')
redis.commands.ldbprint = redis.command('P')
redis.commands.ldbeval = redis.command('E')
redis.commands.ldbtrace = redis.command('T')
redis.commands.ldbredis = redis.command('R')

-- connect to redis instance
local client = redis.connect({host = host, port = port, timeout = 0.5})
client.error = function(error) return nil, (error:gsub(".+ERR ","")) end

-- authenticate if password is provided
local msg, err = client:ping()
if not msg and err:find("NOAUTH") then
  check(password, "Authentication is required, but no password is provided to authenticate.")
  check(client:auth(password), "Can't autheticate with the provided password.")
end

-- start debugging
msg, err = check(client:raw_cmd("SCRIPT DEBUG "..rundebug))

-- split passed parameters into KEYS and ARGV (separated by ',')
local keys = #params
for n, v in ipairs(params) do
  if v == ',' then
    keys = n - 1
    table.remove(params, n)
    break
  end
end
-- load the script to debug; check for any reported errors
msg, err = check(client:eval(code, keys, unpack(params)))
if msg and isdone(msg) then msg, err = check(client:ping()) end

-- if no debugging is requested, nothing else is needed to be done
if not rundebug or rundebug == "no" then
  client:quit()
  os.exit(0)
end

-- connect to the debugger
local server, err = socket.tcp()
check(server, ("Can't open socket: %s"):format(err))

host, port = controller:match("^%s*(.+):(%d+)%s*$")
check(host and port, ("Unknown debugger address format '%s'; expected host:port."):format(controller))

if server.settimeout then server:settimeout(2) end
local ok, err = server:connect(host, port)
if server.settimeout then server:settimeout() end
check(ok, ("Can't connect to the debugger at '%s': %s"):format(controller, err))

-- main debugger loop
local basedir
while true do
  local line = check(server:receive())
  local command = string.sub(line, string.find(line, "^[A-Z]+"))
  if command == "SETB" or command == "DELB" then
    local _, _, _, lfile, line = string.find(line, "^([A-Z]+)%s+(.-)%s+(%d+)%s*$")
    if lfile and line then
      line = line == "0" and 0 or (command == "SETB" and tonumber(line) or -tonumber(line))
      -- deleting from file '*' deletes all breakpoints
      if lfile == '*' or isfilesame(file, lfile, basedir) then client:ldbbreakpoint(line) end
      server:send("200 OK\n")
    else
      server:send("400 Bad Request\n")
    end
  elseif command == "BASEDIR" then
    local _, _, dir = string.find(line, "^[A-Z]+%s+(.+)%s*$")
    if dir then
      basedir = dir
      server:send("200 OK\n")
    else
      server:send("400 Bad Request\n")
    end
  elseif command == "LOAD" then
    local _, _, size = string.find(line, "^[A-Z]+%s+(%d+)%s+(%S.-)%s*$")
    size = tonumber(size)

    if size > 0 then server:receive(size) end
    server:send("201 Started " .. file .. " " .. (getline(msg) or 1) .. "\n")
  elseif command == "RUN" then
    server:send("200 OK\n")
    local msg, err = client:ldbcontinue()
    local done = isdone(msg)
    -- if the session is done, need to read the error value (if any)
    if done then msg, err = client:ping() end
    if err then
      server:send("401 Error in Execution " .. tostring(#err) .. "\n")
      server:send(err)
    elseif not done then
      server:send("202 Paused " .. file .. " " .. (getline(msg) or 0) .. "\n")
    end
    if done then
      client:quit()
      break
    end
  elseif command == "STEP" or command == "OVER" or command == "OUT" then
    server:send("200 OK\n")
    local msg, err = client:ldbstep()

    -- check if this is the last step stopped at "out of range" position; do one more step
    if msg and #getval(msg, "->%s+%d+%s+<out of range") > 0 then msg, err = client:ldbstep() end
    local done = isdone(msg)
    -- if the session is done, need to read the error value (if any)
    if done then msg, err = client:ping() end
    if err then
      server:send("401 Error in Execution " .. tostring(#err) .. "\n")
      server:send(err)
    elseif not done then
      server:send("202 Paused " .. file .. " " .. (getline(msg) or 0) .. "\n")
    end
    if done then
      client:quit()
      break
    end
  elseif command == "EXEC" then
    local _, _, chunk = string.find(line, "^[A-Z]+%s+(.+)$")
    if chunk then
      local func, err = loadstring(chunk)
      if not func then
        local chunkr = "return "..chunk
        func = loadstring(chunkr)
        if func then chunk = chunkr end
      end
      if func then
        -- evaluation is done in a different environment, so capture local variables
        -- to use in the chunk evaluation to make their values available
        local preamble = getlocals(client:ldbprint())
        local msg, err = client:ldbeval(preamble..chunk)
        -- if there is an error, try without preamble, as it has a better error message
        if msg and geterror(msg) then msg, err = client:ldbeval(chunk) end
        if msg and geterror(msg) then msg, err = nil, geterror(msg) end
        if msg then
          -- if the chunk starts from "return" or looks like an expression, then return the result
          -- otherwise don't return any values to avoid showing `nil` after statements.
          msg = (chunk:find("^return ") or loadstring("return "..chunk)) and getretval(msg) or "return {}"
          server:send("200 OK " .. tostring(#msg) .. "\n")
          server:send(msg)
        else
          server:send("401 Error in Expression " .. tostring(#err) .. "\n")
          server:send(err)
        end
      elseif chunk:find("^[A-Z][A-Z]+%s") then
        local cmd = {}
        for v in chunk:gmatch("(%S+)") do table.insert(cmd, v) end
        local msg, err = client:ldbredis(unpack(cmd))
        if msg and geterror(msg) then msg, err = nil, geterror(msg) end
        if msg then
          msg = getreply(msg)
          server:send("200 OK " .. tostring(#msg) .. "\n")
          server:send(msg)
        else
          server:send("401 Error in Expression " .. tostring(#err) .. "\n")
          server:send(err)
        end
      else
        server:send("401 Error in Expression " .. tostring(#err) .. "\n")
        server:send(err)
      end
    else
      server:send("400 Bad Request\n")
    end
  elseif command == "STACK" then
    -- get stack information and repackage it in the expected format
    local msg = "return {}"
    server:send("200 OK " .. tostring(msg) .. "\n")
  elseif command == "DONE" then
    client:ldbbreakpoint(0) -- remove all breakpoints
    client:ldbcontinue() -- continue with the script
    break
  elseif command == "EXIT" then
    client:ldbabort()
    server:send("200 OK\n")
    break
  elseif command == "SETW" or command == "DELW" or command == "SUSPEND" or command == "OUTPUT" then
    server:send("200 OK\n")
  else
    server:send("400 Bad Request\n")
  end
end

--[[ configuration example:
redis = {debugmode = "sync"} -- the default debug mode is "yes"
--]]
