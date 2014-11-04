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
%% @doc Watchdog for IO
%% @reference
%% @end
%%======================================================================
-module(leo_watchdog_io).

-author('Yosuke Hara').

-behaviour(leo_watchdog_behaviour).

-include("leo_watchdog.hrl").
-include_lib("eunit/include/eunit.hrl").

%% API
-export([start_link/4,
         stop/0]).

%% Callback
-export([handle_call/2,
         handle_fail/2]).

-record(state, {
          max_input  = 0  :: pos_integer(),
          max_output = 0  :: pos_integer(),
          callback_mod    :: module(),
          prev_input  = 0 :: pos_integer(),
          prev_output = 0 :: pos_integer(),
          interval = timer:seconds(1) :: pos_integer()
         }).


%%--------------------------------------------------------------------
%% API
%%--------------------------------------------------------------------
%% @doc Start the server
-spec(start_link(MaxInputForInterval, MaxOutputForInterval,
                 CallbackMod, Interval) ->
             {ok,Pid} |
             ignore |
             {error,Error} when MaxInputForInterval::non_neg_integer(),
                                MaxOutputForInterval::non_neg_integer(),
                                CallbackMod::module(),
                                Interval::pos_integer(),
                                Pid::pid(),
                                Error::{already_started,Pid} | term()).
start_link(MaxInputForInterval, MaxOutputForInterval, CallbackMod, Interval) ->
    State = #state{max_input    = MaxInputForInterval,
                   max_output   = MaxOutputForInterval,
                   callback_mod = CallbackMod,
                   prev_input   = MaxInputForInterval,
                   prev_output  = MaxOutputForInterval,
                   interval     = Interval
                  },
    leo_watchdog:start_link(?MODULE, ?MODULE, State, Interval).


%% @doc Stop the server
-spec(stop() ->
             ok).
stop() ->
    leo_watchdog:stop(?MODULE).


%%--------------------------------------------------------------------
%% Callback
%%--------------------------------------------------------------------
%% @dog Call execution of the watchdog
-spec(handle_call(Id, State) ->
             {ok, State} |
             {{error,Error}, State} when Id::atom(),
                                         State::#state{},
                                         Error::any()).
handle_call(Id, #state{max_input    = MaxInput,
                       max_output   = MaxOutput,
                       callback_mod = CallbackMod,
                       prev_input   = PrevInput,
                       prev_output  = PrevOutput,
                       interval     = Interval} = State) ->
    RetL = tuple_to_list(erlang:statistics(io)),
    CurInput  = leo_misc:get_value('input',  RetL, 0),
    CurOutput = leo_misc:get_value('output', RetL, 0),
    DiffInput  = CurInput  - PrevInput,
    DiffOutput = CurOutput - PrevOutput,

    CurState = [{prev_input,  PrevInput},
                {prev_output, PrevOutput},
                {cur_input,   CurInput},
                {cur_output,  CurOutput},
                {diff_input,  DiffInput},
                {diff_output, DiffOutput}
               ],
    CurState_1 = #watchdog_state{props = CurState},
    CurTotalIO = DiffInput + DiffOutput,
    ThresholdIO = erlang:round((MaxInput + MaxOutput) * Interval),

    {Level, CurState_2} =
        case (CurTotalIO > ThresholdIO) of
            true ->
                {?WD_LEVEL_ERROR,
                 CurState_1#watchdog_state{state = ?WD_LEVEL_ERROR}};
            false ->
                {?WD_LEVEL_SAFE,
                 CurState_1#watchdog_state{state = ?WD_LEVEL_SAFE}}
        end,

    %% If level is warning or error,
    %% nofify the message to the clients
    ?notify_msg(Id, CallbackMod, Level, CurState_2),
    catch leo_watchdog_state:put(?MODULE, CurState_2),
    {ok, State#state{prev_input  = CurInput,
                     prev_output = CurOutput}}.


%% @dog Call execution failed
-spec(handle_fail(Id, Cause) ->
             ok | {error,Error} when Id::atom(),
                                     Cause::any(),
                                     Error::any()).
handle_fail(_Id,_Cause) ->
    ok.


%%--------------------------------------------------------------------
%% Internal Function
%%--------------------------------------------------------------------
