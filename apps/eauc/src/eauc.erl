-module(eauc).
-behaviour(supervisor).
-behaviour(application).
-export([init/1, start/2, start/0, stop/1, main/1]).

main(A)    -> mad:main(A).
start()    ->
  application:ensure_all_started(eauc).

start(_,_) ->
  application:start(ssl),
  supervisor:start_link({local,eauc},eauc,[]).

stop(_)    -> ok.

init([])   ->
  Params = #{
    host => "localhost",
    port => 5432,
    username => "postgres",
    password => "",
    database => "eauc"
  },

  case epgsql_pool:start(my_main_pool, 50, 100, Params) of
    {ok, _} ->
      io:format("~p~n",["pg_pool start !!"]);
    Z ->
      io:format("Pool start err: ~p~n~p~n", ["err db connect", Z])
  end,

  {ok, {{one_for_one, 5, 10},
        [spec(),
         #{id => lot_worker_1,
           start => {worker_inactive_lot, start_link, []},
           restart => permanent,
           type => worker,
           modules => [worker_inactive_lot] },
         #{id => bet_worker_1,
           start => {worker_bets, start_link, []},
           restart => permanent,
           type => worker,
           modules => [worker_bets] }
  ]}}.

spec()   -> ranch:child_spec(http, 100, ranch_tcp, port(), cowboy_protocol, env()).
env()    -> [ { env, [ { dispatch, points() } ] } ].
%static() ->   { dir, "apps/eauc/priv/static", mime() }.
%n2o()    ->   { dir, "deps/n2o/priv",           mime() }.
%mime()   -> [ { mimetypes, cow_mimetypes, all   } ].
port()   -> [ { port, wf:config(n2o,port,8000)  } ].
points() -> cowboy_router:compile([{'_', [

%    {"/static/[...]",       n2o_static,  static()},
%    {"/n2o/[...]",          n2o_static,  n2o()},
    {"/multipart/[...]",  n2o_multipart, []},
    {"/ws/[...]",           n2o_stream,  []},
    {'_',                   n2o_cowboy,  []} ]}]).

