%% This Source Code Form is subject to the terms of the Mozilla Public
%% License, v. 2.0. If a copy of the MPL was not distributed with this
%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%
%% Copyright (c) 2026 TsjipTsjip. All Rights Reserved.

-module(rabbit_mgmt_wm_queue_peek).

-export([init/2, is_authorized/2, content_types_provided/2, to_json/2]).

-include_lib("rabbitmq_management_agent/include/rabbit_mgmt_records.hrl").
-include_lib("rabbit_common/include/rabbit.hrl").

%%--------------------------------------------------------------------

%% COWBOY INIT CALLBACK - Use rabbit_mgmt_headers:set_common_permission_headers as all REST handlers seem to do. Also generate an empty context map.
init(Req, _State) ->
    {cowboy_rest, rabbit_mgmt_headers:set_common_permission_headers(Req, ?MODULE), #context{}}.

%% COWBOY CONTENT TYPES CALLBACK - This is, again, is following RabbitMQ's handlers examples.
content_types_provided(ReqData, Context) ->
   {rabbit_mgmt_util:responder_map(to_json), ReqData, Context}.

%% COWBOY IS_AUTHORIZED CALLBACK - Gatekeeper that checks if the user has read access to the vHost. RabbitMQ provides this for us.
is_authorized(ReqData, Context) ->
    rabbit_mgmt_util:is_authorized_vhost(ReqData, Context).

%% GET HANDLER - Main logic method that produces a json response, wired above by content_types_provided into cowboy.
to_json(ReqData, Context) ->
    VHost = rabbit_mgmt_util:vhost(ReqData),
    QueueName = rabbit_mgmt_util:id(queue, ReqData),
    PositionStr = rabbit_mgmt_util:id(position, ReqData),
    
    %% Check vhost
    case rabbit_vhost:exists(VHost) of
        false ->
            rabbit_mgmt_util:not_found(
              <<"Target vHost does not exist">>, ReqData, Context);
        true ->
            %% Check queue
            case rabbit_mgmt_wm_queue:queue(ReqData) of
                not_found ->
                    rabbit_mgmt_util:not_found(
                      <<"Target queue does not exist">>, ReqData, Context);
                _ ->
                    %% Parse and validate position
                    case parse_position(PositionStr) of
                        {error, Reason} ->
                            rabbit_mgmt_util:bad_request(Reason, ReqData, Context);
                        {ok, Position} ->
                            %% Call peek, this only exists for quorum queues.
                            case rabbit_quorum_queue:peek(VHost, QueueName, Position) of
                                {ok, Message} ->
                                    rabbit_log:info("peek message = ~tp", [Message]),

                                    FormattedMessage = format_message(Message),

                                    Result = #{
                                        <<"result">> => <<"ok">>,
                                        <<"message">> => FormattedMessage
                                    },

                                    rabbit_mgmt_util:reply(Result, ReqData, Context);
                                {error, not_found} ->
                                    %% In a programmer's last famous words, this error case should never be hit as we've checked the existence of the queue prior.
                                    %% But... rabbit_quorum_queue:peek doesn't know about the queue, we have nothing to return. Match the same error output anyways.
                                    rabbit_mgmt_util:not_found(
                                      <<"Target queue does not exist">>, ReqData, Context);
                                {error, no_message_at_pos} ->
                                    rabbit_mgmt_util:bad_request(
                                      <<"Target queue does not have a message at that position">>,
                                      ReqData, Context);
                                {error, classic_queue_not_supported} ->
                                    rabbit_mgmt_util:bad_request(
                                      <<"Cannot peek into a classic queue">>,
                                      ReqData, Context);
                                Error ->
                                    %% Something else happened which we didn't code a path for. Try to serialise it and report it as our fault.
                                    rabbit_mgmt_util:internal_server_error(
                                      iolist_to_binary(io_lib:format("~tp", [Error])),
                                      ReqData, Context)
                            end
                    end
            end
    end.

%%--------------------------------------------------------------------

%% A peeked position must be parseable as an integer, and must be strictly positive.
parse_position(PositionStr) ->
    case catch binary_to_integer(PositionStr) of
        Pos when is_integer(Pos), Pos >= 1 ->
            {ok, Pos};
        Pos when is_integer(Pos), Pos < 1 ->
            {error, <<"position must be a strictly positive integer (>= 1)">>};
        _ ->
            {error, <<"position must be a valid positive integer">>}
    end.

%% Helper for formatting a message that was just peeked from a queue.
format_message(Message) when is_list(Message) ->
    maps:from_list(
        [{normalize_key(K), format_value(V)} || {K, V} <- Message]
    ).

%% normalize_key produces binary, which is needed for cowboy to serialise into json further down the line.
normalize_key(K) when is_binary(K) -> %% If already binary don't touch it.
    K;
normalize_key(K) when is_atom(K) -> %% If an atom, convert to binary.
    atom_to_binary(K, utf8);
normalize_key(K) -> %% If anything else, convert it to an Erlang iolist format string first, which then converts to binary.
    iolist_to_binary(io_lib:format("~tp", [K])).

%% format_value follows normalize_key somewhat. We're basically flattening things to marshal them into a json response.
format_value(V) when is_binary(V) -> %% If binary don't touch it.
    V;
format_value(V) when is_atom(V) -> %% If an Erlang atom, convert to binary.
    atom_to_binary(V, utf8);
format_value(V) when is_list(V) -> %% If a list, format the values in the list recursively.
    [format_value(X) || X <- V];
format_value(V) -> %% Default case, just return the value itself and let cowboy handle it, which it will, only the output may look slightly ugly.
    V.
