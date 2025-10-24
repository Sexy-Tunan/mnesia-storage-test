%%%-------------------------------------------------------------------
%%% @author Administrator
%%% @copyright (C) 2025, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 24. 10月 2025 16:20
%%%-------------------------------------------------------------------
-module(tester).
-author("Administrator").

-behavior(gen_server).
%% API
-export([start/0, stop/0]).
-export([test_disc_copies/0, test_disc_only_copies/0, loop_insert/1]).
%% gen_server 回调接口
-export([init/1, handle_info/2, handle_call/3, handle_cast/2, terminate/2]).


-record(user1,{name,password}).
-record(user2,{name,password}).

start() ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).
stop() ->
	gen_server:cast(?MODULE, stop).

test_disc_copies() -> gen_server:call(?MODULE, disc_copies).

test_disc_only_copies() -> gen_server:call(?MODULE, disc_only_copies).

%% =============================
%% gen_server 回调模块
%% 初始化
init([]) ->
	%% 初始化mnesia
	mnesia:create_schema([node()]),
	mnesia:start(),
	{ok, #{}}.


handle_call(disc_copies, _From, State) ->
	%% 建表
	mnesia:create_table(user1, [{attributes, record_info(fields,user1)},{disc_copies, [node()]}]),
	%% 一直插入
	spawn(fun() -> loop_insert(1) end),
%%	try

%%	catch
%%		throw:Reason -> {insert, thrown, Reason};
%%		exit:Reason -> {insert, exit, Reason};
%%		error:Reason -> {insert, exit, Reason}
%%	end,
	{reply, ok, State};


handle_call(disc_only_copies, _From, State) ->
	mnesia:create_table(user2, [{attributes, record_info(fields,user2)},{disc_only_copies, [node()]}]),
	loop_insert2(1),
	{reply, ok, State};


handle_call(_Req, _From, State) ->
	{reply, ok, State}.

handle_info(_Msg, State) ->
	{noreply, State}.

handle_cast(_, State) ->
	{noreply, State}.

terminate(_Reason, _State) ->
	io:format("啊哈"),
	ok.



loop_insert(Num) ->
	try
		io:format("disc_copies --> 插入第~p条~n", [Num]),
		LargeBin = list_to_binary(lists:duplicate(1024*100, $x)),
		F = fun() -> mnesia:write(#user1{name = io_lib:format("Robot_~p", [Num]), password = LargeBin}) end,
		{atomic, ok} = mnesia:transaction(F),
		loop_insert(Num + 1)
	catch
		throw:Reason -> io:format("throw = [~p]~n", [Reason]), {insert,Num, thrown, Reason};
		exit:Reason -> io:format("exit = [~p]~n", [Reason]), {insert,Num, exit, Reason};
		error:Reason -> io:format("error = [~p]~n", [Reason]), {insert,Num, exit, Reason}
	end.


loop_insert2(Num) ->
	ok.