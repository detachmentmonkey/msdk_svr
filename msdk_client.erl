-module (msdk_client).
-export ([connect/2, send/1]).

connect(Address, Port, Options)->
    {ok, Socket} = gen_tcp:connect(Address, Port, Options),