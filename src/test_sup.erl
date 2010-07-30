%%   The contents of this file are subject to the Mozilla Public License
%%   Version 1.1 (the "License"); you may not use this file except in
%%   compliance with the License. You may obtain a copy of the License at
%%   http://www.mozilla.org/MPL/
%%
%%   Software distributed under the License is distributed on an "AS IS"
%%   basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
%%   License for the specific language governing rights and limitations
%%   under the License.
%%
%%   The Original Code is RabbitMQ.
%%
%%   The Initial Developers of the Original Code are LShift Ltd,
%%   Cohesive Financial Technologies LLC, and Rabbit Technologies Ltd.
%%
%%   Portions created before 22-Nov-2008 00:00:00 GMT by LShift Ltd,
%%   Cohesive Financial Technologies LLC, or Rabbit Technologies Ltd
%%   are Copyright (C) 2007-2008 LShift Ltd, Cohesive Financial
%%   Technologies LLC, and Rabbit Technologies Ltd.
%%
%%   Portions created by LShift Ltd are Copyright (C) 2007-2010 LShift
%%   Ltd. Portions created by Cohesive Financial Technologies LLC are
%%   Copyright (C) 2007-2010 Cohesive Financial Technologies
%%   LLC. Portions created by Rabbit Technologies Ltd are Copyright
%%   (C) 2007-2010 Rabbit Technologies Ltd.
%%
%%   All Rights Reserved.
%%
%%   Contributor(s): ______________________________________.
%%

-module(test_sup).

-behaviour(supervisor2).

-export([test_supervisor_delayed_restart/0,
         init/1, start_child/0]).

test_supervisor_delayed_restart() ->
    passed = with_sup(simple_one_for_one_terminate,
                      fun (SupPid) ->
                              {ok, _ChildPid} =
                                  supervisor2:start_child(SupPid, []),
                              test_supervisor_delayed_restart(SupPid)
                      end),
    passed = with_sup(one_for_one, fun test_supervisor_delayed_restart/1).

test_supervisor_delayed_restart(SupPid) ->
    ok = ping_child(SupPid),
    ok = exit_child(SupPid),
    timer:sleep(10),
    ok = ping_child(SupPid),
    ok = exit_child(SupPid),
    timer:sleep(10),
    timeout = ping_child(SupPid),
    timer:sleep(1010),
    ok = ping_child(SupPid),
    passed.

with_sup(RestartStrategy, Fun) ->
    {ok, SupPid} = supervisor2:start_link(?MODULE, [RestartStrategy]),
    Res = Fun(SupPid),
    exit(SupPid, shutdown),
    rabbit_misc:unlink_and_capture_exit(SupPid),
    Res.

init([RestartStrategy]) ->
    {ok, {{RestartStrategy, 1, 1},
          [{test, {test_sup, start_child, []}, {permanent, 1},
            16#ffffffff, worker, [test_sup]}]}}.

start_child() ->
    {ok, proc_lib:spawn_link(fun run_child/0)}.

ping_child(SupPid) ->
    Ref = make_ref(),
    get_child_pid(SupPid) ! {ping, Ref, self()},
    receive {pong, Ref} -> ok
    after 1000          -> timeout
    end.

exit_child(SupPid) ->
    true = exit(get_child_pid(SupPid), abnormal),
    ok.

get_child_pid(SupPid) ->
    [{_Id, ChildPid, worker, [test_sup]}] =
        supervisor2:which_children(SupPid),
    ChildPid.

run_child() ->
    receive {ping, Ref, Pid} -> Pid ! {pong, Ref},
                                run_child()
    end.
