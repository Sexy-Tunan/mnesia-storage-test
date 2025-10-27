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
-export([test_disc_copies/0, test_disc_only_copies/0]).
-export([get_storage_stats/1]).
-export([loop_insert/1, loop_insert2/1]).
%% gen_server 回调接口
-export([init/1, handle_info/2, handle_call/3, handle_cast/2, terminate/2]).


-record(user1,{name,password}).
-record(user2,{name,password}).

start() ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

stop() ->
	gen_server:cast(?MODULE, stop).

test_disc_copies() -> 
	gen_server:call(?MODULE, disc_copies).

test_disc_only_copies() -> 
	gen_server:call(?MODULE, disc_only_copies).

%% 获取表的存储统计信息
get_storage_stats(Table) ->
	try
		Size = mnesia:table_info(Table, size),
		Memory = mnesia:table_info(Table, memory),
		StorageType = mnesia:table_info(Table, storage_type),
		MemoryMB = Memory * 8 / (1024 * 1024),
		Total = erlang:memory(total),
		EtsMemory = erlang:memory(ets),
		{ok, #{ table => Table,
				records => Size,
				memory_words => Memory,
				memory_mb => MemoryMB,
				disc_use => Memory / (1024 * 1024),
				storage_type => StorageType,
				total => Total/(1024*1024),
				ets_memory => EtsMemory/(1024*1024)
			}
		}
	catch
		_:Reason ->
			{error, #{reason => Reason, table => Table}}
	end.

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
	case mnesia:create_table(user1, [{attributes, record_info(fields,user1)},{disc_copies, [node()]}]) of
		{atomic, ok} ->
			%% 因为handle_call是有返回值的，所以需要通过启动另一个进程循环插入处理，否则在handle_call0=中进入循环插入是会阻塞等待返回结果，shell也不会有输出
			%% 启动插入进程
			{ok, DataMap} = get_storage_stats(user1),
			io:format("~n--- 初始信息 (disc_copies) ---~n"),
			io:format("表中记录数: ~p~n", [maps:get(records, DataMap, unknown)]),
			%% 特别说明 table_info中的memory选项，对于disk_only_copies是返回的存储在磁盘上的字节数
			io:format("表元信息占用: ~.2f MB~n", [maps:get(memory_mb, DataMap, 0)]),
			io:format("ErLang总内存占用: ~.2f MB~n", [maps:get(total, DataMap, 0)]),
			io:format("ets内存占用: ~.2f MB~n", [maps:get(ets_memory, DataMap, 0)]),
			io:format("-------------------------------~n~n"),

			spawn(fun() -> loop_insert(1) end),
			{reply, {ok, started}, State};
%%		{aborted, {already_exists, user1}} ->
%%			io:format("表 user1 已存在，继续使用~n"),
%%			{reply, {ok, already_exists}, State};
		Error ->
			io:format("创建表失败: ~p~n", [Error]),
			{reply, {error, Error}, State}
	end;

handle_call(disc_only_copies, _From, State) ->
	%% 建表
	case mnesia:create_table(user2, [{attributes, record_info(fields,user2)},{disc_only_copies, [node()]}]) of
		{atomic, ok} ->
			{ok, DataMap} = get_storage_stats(user2),
			io:format("~n--- 初始信息 (disc_only_copies) ---~n"),
			io:format("表中记录数: ~p~n", [maps:get(records, DataMap, unknown)]),
			%% 特别说明 table_info中的memory选项，对于disk_only_copies是返回的存储在磁盘上的字节数
			io:format("磁盘占用: ~.2f MB~n", [maps:get(disc_use, DataMap, 0)]),
			io:format("ErLang总内存占用: ~.2f MB~n", [maps:get(total, DataMap, 0)]),
			io:format("ets内存占用: ~.2f MB~n", [maps:get(ets_memory, DataMap, 0)]),
			io:format("-------------------------------~n~n"),
			%% 启动插入进程
			spawn(fun() -> loop_insert2(1) end),
			{reply, {ok, started}, State};
%%		{aborted, {already_exists, user2}} ->
%%			io:format("表 user2 已存在，继续使用~n"),
%%			{reply, {ok, already_exists}, State};
		Error ->
			io:format("创建表失败: ~p~n", [Error]),
			{reply, {error, Error}, State}
	end;


handle_call(_Req, _From, State) ->
	{reply, ok, State}.

handle_info(_Msg, State) ->
	{noreply, State}.

handle_cast(stop, State) ->
	io:format("收到停止信号，准备关闭...~n"),
	{stop, normal, State};

handle_cast(_Msg, State) ->
	{noreply, State}.

terminate(_Reason, _State) ->
	mnesia:stop(),
	ok.

loop_insert(Num) ->
	try
		%% 每10条记录输出一次进度
		case Num rem 10 of
			0 -> io:format("disc_copies --> 已插入~p条记录~n", [Num]);
			_ -> ok
		end,
		%% 每100条记录输出详细统计
		case Num rem 100 of
			0 ->
				{ok,DataMap} = get_storage_stats(user1),
				io:format("~n--- 阶段性统计 (disc_copies) ---~n"),
				io:format("尝试插入: ~p 条记录~n", [Num]),
				io:format("表中实际记录数: ~p~n", [maps:get(records, DataMap, unknown)]),
				io:format("表元信息及索引结构内存占用: ~.2f MB~n", [maps:get(memory_mb, DataMap, 0)]),
				io:format("ErLang总内存占用: ~.2f MB~n", [maps:get(total, DataMap, 0)]),
				io:format("ets内存占用: ~.2f MB~n", [maps:get(ets_memory, DataMap, 0)]),
				io:format("-------------------------------~n~n");
			_ -> ok
		end,
		
		%% 创建1MB的大数据记录
		LargeBin = list_to_binary(lists:duplicate(1024*1024, $x)),
		KeyName = lists:flatten(io_lib:format("Robot_~p", [Num])),
		F = fun() -> mnesia:write(#user1{name = KeyName, password = LargeBin}) end,
		{atomic, ok} = mnesia:transaction(F),
		loop_insert(Num + 1)
	catch
		throw:Reason -> 
			io:format("~n!!! 插入失败 (throw) !!!~n第~p条记录~n原因: ~p~n", [Num, Reason]), 
			{insert, Num, thrown, Reason};
		exit:Reason -> 
			io:format("~n!!! 插入失败 (exit) !!!~n第~p条记录~n原因: ~p~n", [Num, Reason]), 
			{insert, Num, exit, Reason};
		error:Reason:Stacktrace -> 
			io:format("~n!!! 插入失败 (error) !!!~n第~p条记录~n原因: ~p~n堆栈: ~p~n", [Num, Reason, Stacktrace]), 
			{insert, Num, error, Reason}
	end.


loop_insert2(Num) ->
	try
		%% 每10条记录输出一次进度
		case Num rem 10 of
			0 -> io:format("disc_only_copies --> 已插入~p条记录~n", [Num]);
			_ -> ok
		end,
		
		%% 每1000条记录输出详细统计
		case Num rem 100 of
			0 ->
				{ok, DataMap} = get_storage_stats(user2),
				io:format("~n--- 阶段性统计 (disc_only_copies) ---~n"),
				io:format("尝试插入: ~p 条记录~n", [Num]),
				io:format("表中实际记录数: ~p~n", [maps:get(records, DataMap, unknown)]),
				%% 特别说明 table_info中的memory选项，对于disk_only_copies是返回的存储在磁盘上的字节数
				io:format("磁盘占用: ~.2f MB~n", [maps:get(disc_use, DataMap, 0)]),
				io:format("ErLang总内存占用: ~.2f MB~n", [maps:get(total, DataMap, 0)]),
				io:format("ets内存占用: ~.2f MB~n", [maps:get(ets_memory, DataMap, 0)]),
				io:format("-------------------------------~n~n");
			_ -> ok
		end,
		
		%% 创建1MB的大数据记录
		LargeBin = list_to_binary(lists:duplicate(1024*1024, $x)),
		KeyName = lists:flatten(io_lib:format("Robot_~p", [Num])),
		F = fun() -> mnesia:write(#user2{name = KeyName, password = LargeBin}) end,
		{atomic, ok} = mnesia:transaction(F),
		loop_insert2(Num + 1)
	catch
		throw:Reason -> 
			io:format("~n!!! 插入失败 (throw) !!!~n第~p条记录~n原因: ~p~n", [Num, Reason]), 
			{insert, Num, thrown, Reason};
		exit:Reason -> 
			io:format("~n!!! 插入失败 (exit) !!!~n第~p条记录~n原因: ~p~n", [Num, Reason]), 
			{insert, Num, exit, Reason};
		error:Reason:Stacktrace -> 
			io:format("~n!!! 插入失败 (error) !!!~n第~p条记录~n原因: ~p~n堆栈: ~p~n", [Num, Reason, Stacktrace]), 
			{insert, Num, error, Reason}
	end.