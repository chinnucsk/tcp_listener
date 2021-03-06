%% -----------------------------------------------------------------------------
%% Copyright © 2010 Per Andersson
%%
%% This file is part of tcp_listener.
%%
%% tcp_listener is free software: you can redistribute it and/or modify
%% it under the terms of the GNU General Public License as published by
%% the Free Software Foundation, either version 3 of the License, or (at your
%% option) any later version.
%%
%% tcp_listener is distributed in the hope that it will be useful,
%% but WITHOUT ANY WARRANTY; without even the implied warranty of
%% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%% GNU General Public License for more details.
%%
%% You should have received a copy of the GNU General Public License
%% along with tcp_listener.  If not, see
%% <http://www.gnu.org/licenses/>.
%% -----------------------------------------------------------------------------
%%
%% @author Per Andersson <avtobiff@gmail.com>
%% @doc
%% TCP Listener Supervisor
%%
%% This module implements supervisors for the tcp_listener and its connections.
%%
%% When the tcp_listener is started a supervisor tree is built.
%%
%% See supervisor(3) for more information.
%% @end
%%
%% -----------------------------------------------------------------------------
-module(tcp_listener_sup).
-author('Per Andersson <avtobiff@gmail.com>').

-behaviour(supervisor).

-include("tcp_listener.hrl").

%% supervisor export
-export([init/1]).

%% external exports
-export([start_acceptor/1]).


%% types
-type child() :: pid() | undefined.

-type error() :: already_present | {already_started, child()} | term().



%% ----------------------------------------------------------------------------
%%
%% SUPERVISOR EXPORTS
%%
%% ----------------------------------------------------------------------------

%% ----------------------------------------------------------------------------
-spec init(Args :: args()) -> Result :: term().
%% @doc
%% @end
%% ----------------------------------------------------------------------------
init(Args) ->
    Supervisor =
        proplists:get_value('$tcp_listener_supervisor', Args,
                            tcp_listener_sup),
    ?DEBUGP("init/1 supervisor = ~p~n", [Supervisor]),
    init(Supervisor, Args).



%% ----------------------------------------------------------------------------
-spec init(tcp_listener | tcp_listener_connection_sup,
           Args :: args()) -> Result :: term();

      (tcp_listener_connection_sup, Args :: args()) ->
            Result :: term().
%% @doc
%% Supervisor definitions.
%%
%% The tcp_listener is supervised by a one_for_one supervisor.
%%
%% Each connection is started dynamically by a simple_one_for_one supervisor.
%% @end
%% ----------------------------------------------------------------------------
init(tcp_listener_sup, Args) ->
    ?DEBUGP("init/2~n"),

    %% build tcp_listener start arguments
    {Registry, SuppliedName} =
        proplists:get_value('$tcp_listener_server_ref', Args),
    Name = list_to_atom("tcp_listener_" ++ atom_to_list(SuppliedName)),
    ServerName = {Registry, Name},
    Opts = proplists:get_value('$tcp_listener_opts', Args, []),

    %% if Name is empty start_link/3 is called, otherwise start_link/4
    ListenerArgs = [ServerName, tcp_listener, Args, Opts],

    ListenerSupName = list_to_atom("tcp_listener_" ++
                                   atom_to_list(SuppliedName) ++ "_sup"),
    ConnectionSupName = list_to_atom("tcp_listener_" ++
                                     atom_to_list(SuppliedName) ++
                                     "_connection_sup"),

    {ok, {{one_for_one, ?SUP_MAX_RESTART, ?SUP_MAX_TIME},
          %% TCP listener supervisor
          [{ListenerSupName,
            {gen_server, start_link, ListenerArgs},
            permanent,
            ?SUP_TIMEOUT,
            worker,
            [tcp_listener]},
          %% TCP connections supervisor
           {ConnectionSupName,
            {supervisor, start_link,
             [{local, ConnectionSupName}, ?MODULE,
              [{'$tcp_listener_supervisor',
                tcp_listener_connection_sup}|Args]]},
            permanent,
            infinity,
            supervisor,
            []}
          ]}};


init(tcp_listener_connection_sup, Args) ->
    Module = proplists:get_value('$tcp_listener_module', Args),

    ?DEBUGP("init/2 tcp_listener_connection_sup.~nmodule = ~p~n",
              [Module]),
    {ok, {{simple_one_for_one, ?SUP_MAX_RESTART, ?SUP_MAX_TIME},
          [{undefined,
            {Module, start_link, []},
            temporary,
            ?SUP_TIMEOUT,
            worker,
            [Module]}
          ]}}.



%% ----------------------------------------------------------------------------
%%
%% EXTERNAL EXPORTS
%%
%% ----------------------------------------------------------------------------

%% ----------------------------------------------------------------------------
%% See top of file for types
-spec start_acceptor(Args :: args()) -> Result :: {ok, child()} | error().
%% @doc
%% @end
%% ----------------------------------------------------------------------------
start_acceptor({_Registry, Name}) ->
    ?DEBUGP("start_client/1~n"),
    ConnectionSupName = list_to_atom("tcp_listener_" ++
                                     atom_to_list(Name) ++
                                     "_connection_sup"),
    {ok, _Pid} = supervisor:start_child(ConnectionSupName, []).
