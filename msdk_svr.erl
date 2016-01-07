-module (msdk_svr). 
-export([listen/1]).
-import (jiffy, [decode/1, decode/2, encode/1, encode/2]).
-import (tools, [sec/0, calc_sig/1]).

-export ([jiffy_test/2]).

jiffy_test(de,Json)-> decode(Json);

jiffy_test(en, Er)-> encode(Er).
 
%% TCP options for our listening socket.  The initial list atom
%% specifies that we should receive data as lists of bytes (ie
%% strings) rather than binary objects and the rest are explained
%% better in the Erlang docs than I can do here.
 
-define(TCP_OPTIONS,[list, {packet, 0}, {active, false}, {reuseaddr, true}]).
 
%% Listen on the given port, accept the first incoming connection and
%% launch the echo loop on it.  This also needs to launch the
%% client_manager proces, since it's our server's entry point.
 
listen(Port) ->
    Pid = spawn(fun() -> manage_clients([]) end),
    register(client_manager, Pid),
    {ok, LSocket} = gen_tcp:listen(Port, ?TCP_OPTIONS),
    do_accept(LSocket).
 
%% The accept gets its own function so we can loop easily.  Yay tail
%% recursion!  We also need to let client_manager know that there's a
%% new socket to manage.
 
do_accept(LSocket) ->
    {ok, Socket} = gen_tcp:accept(LSocket),
    spawn(fun() -> handle_client(Socket) end),
    client_manager ! {connect, Socket},
    do_accept(LSocket).
 
%% handle_client/1 replaces do_echo/1 because we now do everything
%% through the client_manager process.  Disconnects notify
%% client_manager that the socket is no longer open and data is sent
%% as-is to be distributed.
 
handle_client(Socket) ->
    case gen_tcp:recv(Socket, 0) of
        {ok, Data} ->
            % 解析req
            {[{"channel", Channel}, {"opertation", Opertation}, {"data", ReqData}]}  = decode(list_to_binary(Data)),
            case process_data(Channel, Opertation, ReqData) of
                {ok, Body} -> 
                    OkMsg = encode({[{"res", "succ"}, {"body", decode(Body)}]}),
                    gen_tcp:send(Socket, OkMsg);
                {error, Reason} -> 
                    ErrMsg = encode({[{"res", "fail"}, {"reason", decode(Reason)}]}),
                    gen_tcp:send(Socket, ErrMsg)
            end,
            % client_manager ! {data, Data},
            handle_client(Socket);
        {error, closed} ->
            client_manager ! {disconnect, Socket}
    end.
 
%% Maintain a list of sockets, handle connect and disconnect messages
%% and distribute data between them.
 
manage_clients(Sockets) ->
    receive
        {connect, Socket} ->
            io:fwrite("Socket connected: ~w~n", [Socket]),
            NewSockets = [Socket | Sockets];
        {disconnect, Socket} ->
            io:fwrite("Socket disconnected: ~w~n", [Socket]),
            NewSockets = lists:delete(Socket, Sockets);
        {data, Data} ->
            send_data(Sockets, Data),
            NewSockets = Sockets
    end,
    manage_clients(NewSockets).
 
%% Send data to all sockets in the list.  This is done by constructing
%% a closure around gen_tcp:send and the data and then passing that to
%% lists:foreach/2 with the list of sockets.
 
send_data(Sockets, Data) ->
    SendData = fun(Socket) ->
                       gen_tcp:send(Socket, Data)
               end,
    lists:foreach(SendData, Sockets).


process_data("qq", "login", ReqData)->
    Url     = list:concat(["http://msdktest.qq.com/auth/verify_login/?timestamp=", timestamp, "&appid=", appid, "&sig=", sig, "&openid=", openid, "&encode=1"]),
    Headers = [],
    Content_type = "application/x-www-form-urlencoded",
    ReqBody = encode(ReqData),
    ssl:start(),
    application:start(inets),
    case httpc:request(post, {Url, Headers, Content_type,ReqBody}, [], []) of
        {ok, {_,_,Body}}-> 
            {ok, Body};  
        {error, Reason}-> 
            io:format("error cause ~p~n",[Reason]),
            {error, Reason}
    end;

process_data("wechat", "login", ReqData)->
    Url     = list:concat(["http://msdktest.qq.com/auth/verify_login/?timestamp=", timestamp, "&appid=", appid, "&sig=", sig, "&openid=", openid, "&encode=1"]),
    Headers = [],
    Content_type = "application/x-www-form-urlencoded",
    ReqBody = encode(ReqData),
    ssl:start(),
    application:start(inets),
    case httpc:request(post, {Url, Headers, Content_type,ReqBody}, [], []) of
        {ok, {_,_,Body}}-> 
            {ok, Body};  
        {error, Reason}-> 
            io:format("error cause ~p~n",[Reason]),
            {error, Reason}
    end;

process_data(_, _, _)->
    {invalid_msg, unhandled_msg}.



% create_req("qq", "login", )->
%     case ReqData of
%         {[{"appid", Appid}, {"openid", Openid}, {"openkey", Openkey}, {"userip", Userip}]}) ->
%             {}
%     end
%     {[{"appid", Appid}, {"openid", Openid}, {"openkey", Openkey}, {"userip", Userip}]})


