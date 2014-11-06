%%======================================================================
%%
%% Leo Watchdog
%%
%% Copyright (c) 2012-2014 Rakuten, Inc.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% @doc leo_watchdog
%% @reference
%% @end
%%======================================================================
-module(leo_watchdog_sup).

-author('Yosuke Hara').

-behaviour(supervisor).

-include("leo_watchdog.hrl").
-include_lib("eunit/include/eunit.hrl").

%% External API
-export([start_link/0,
         start_child/3,
         start_subscriber/3
        ]).

%% Callbacks
-export([init/1]).


%%-----------------------------------------------------------------------
%% API-1
%%-----------------------------------------------------------------------
%% @doc Creates a supervisor process as part of a supervision tree
%% @end
start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).


%%-----------------------------------------------------------------------
%% API-2
%%-----------------------------------------------------------------------
%% @doc Creates the gen_server process as part of a supervision tree
%% @end
-spec(start_child(Type, Args, Interval) ->
             ok | no_return() when Type::rex|cpu|io|disk,
                                   Args::[any()],
                                   Interval::pos_integer()).
start_child(Type, Args, Interval) ->
    case supervisor:start_child(?MODULE, child_spec(Type, Args, Interval * 1000)) of
        {ok, _Pid} ->
            ok;
        Cause ->
            {error, Cause}
    end.

%% @private
child_spec(rex, Args, Interval) ->
    {leo_watchdog_rex,
     {leo_watchdog_rex, start_link, Args ++ [Interval]},
     permanent,
     2000,
     worker,
     [leo_watchdog_rex]};
child_spec(cpu, Args, Interval) ->
    {leo_watchdog_cpu,
     {leo_watchdog_cpu, start_link, Args ++ [Interval]},
     permanent,
     2000,
     worker,
     [leo_watchdog_cpu]};
child_spec(io, Args, Interval) ->
    {leo_watchdog_io,
     {leo_watchdog_io, start_link, Args ++ [Interval]},
     permanent,
     2000,
     worker,
     [leo_watchdog_io]};
child_spec(disk, Args, Interval) ->
    {leo_watchdog_disk,
     {leo_watchdog_disk, start_link, Args ++ [Interval]},
     permanent,
     2000,
     worker,
     [leo_watchdog_disk]}.


%% @doc Creates the gen_server process as part of a supervision tree
%%      <pre>callback_mod need to implement "leo_notify_behaviour"<pre>
%% @end
-spec(start_subscriber(SubId, FilterSrcL, CallbackMod) ->
             ok | no_return() when SubId::atom(),
                                   FilterSrcL::[any()],
                                   CallbackMod::module()).
start_subscriber(SubId, FilterSrcL, CallbackMod) ->
    FilterSrcL_1 = [{src, Filter} || Filter <- FilterSrcL],
    Spec = {SubId,
            {leo_watchdog_sub, start_link, [SubId, FilterSrcL_1, CallbackMod]},
            permanent,
            2000,
            worker,
            [leo_watchdog_sub]},
    case supervisor:start_child(?MODULE, Spec) of
        {ok, _Pid} ->
            ok;
        Cause ->
            {error, Cause}
    end.

%% @private


%% ---------------------------------------------------------------------
%% Callbacks
%% ---------------------------------------------------------------------
%% @doc supervisor callback - Module:init(Args) -> Result
%% @end
init([]) ->
    {ok, {{one_for_one, 5, 60}, []}}.
