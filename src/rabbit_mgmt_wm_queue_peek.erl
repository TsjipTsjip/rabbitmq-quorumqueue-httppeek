%% This Source Code Form is subject to the terms of the Mozilla Public
%% License, v. 2.0. If a copy of the MPL was not distributed with this
%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%
%% Copyright (c) 2026 TsjipTsjip. All Rights Reserved.

-module(rabbit_mgmt_wm_queue_peek).

-export([init/2, resource_exists/2, is_authorized/2, allowed_methods/2,
         content_types_provided/2, to_json/2]).
-export([variances/2]).

-include_lib("rabbitmq_management_agent/include/rabbit_mgmt_records.hrl").
-include_lib("rabbit_common/include/rabbit.hrl").

%%--------------------------------------------------------------------

init(Req, _State) ->
    {cowboy_rest, rabbit_mgmt_headers:set_common_permission_headers(Req, ?MODULE), #context{}}.

variances(Req, Context) ->
    {[<<"accept-encoding">>, <<"origin">>], Req, Context}.

allowed_methods(ReqData, Context) ->
    {[<<"GET">>, <<"OPTIONS">>], ReqData, Context}.

content_types_provided(ReqData, Context) ->
   {rabbit_mgmt_util:responder_map(to_json), ReqData, Context}.

%% Helper to determine if a given (vhost, queue, queueposition) tuple exists at this time, read from request data.
resource_exists(ReqData, Context) ->
    VHost = rabbit_mgmt_util:vhost(ReqData),
    PositionStr = rabbit_mgmt_util:id(position, ReqData),
    
    %% Check if vhost exists
    VHostExists = case VHost of
        not_found -> false;
        VH -> rabbit_vhost:exists(VH)
    end,
    
    %% Check if queue exists (only if vhost exists)
    QueueExists = case VHostExists of
        false -> false;
        true ->
            case rabbit_mgmt_wm_queue:queue(ReqData) of
                not_found -> false;
                _ -> true
            end
    end,
    
    %% Validate position parameter exists and is parseable
    PositionValid = case PositionStr of
        not_found -> false;
        PS -> case parse_position(PS) of
            {ok, _} -> true;
            {error, _} -> false
        end
    end,
    
    %% Resource exists only if all three conditions are met
    ResourceExists = VHostExists andalso QueueExists andalso PositionValid,
    
    {ResourceExists, ReqData, Context}.

%% Main logic method that produces a json response, wired above by content_types_provided into cowboy.
to_json(ReqData, Context) ->
    VHost = rabbit_mgmt_util:vhost(ReqData),
    QueueName = rabbit_mgmt_util:id(queue, ReqData),
    PositionStr = rabbit_mgmt_util:id(position, ReqData),
    
    %% Check vhost
    case rabbit_vhost:exists(VHost) of
        false ->
            rabbit_mgmt_util:not_found(
              <<"vhost">>, VHost, ReqData, Context);
        true ->
            %% Check queue
            case rabbit_mgmt_wm_queue:queue(ReqData) of
                not_found ->
                    rabbit_mgmt_util:not_found(
                      <<"queue">>, QueueName, ReqData, Context);
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
                                    rabbit_mgmt_util:not_found(
                                      <<"queue">>, QueueName, ReqData, Context);
                                {error, no_message_at_pos} ->
                                    rabbit_mgmt_util:bad_request(
                                      <<"Target queue does not have a message at that position">>,
                                      ReqData, Context);
                                {error, classic_queue_not_supported} ->
                                    rabbit_mgmt_util:bad_request(
                                      <<"Cannot peek into a classic queue">>,
                                      ReqData, Context);
                                Error ->
                                    rabbit_mgmt_util:internal_server_error(
                                      iolist_to_binary(io_lib:format("~tp", [Error])),
                                      ReqData, Context)
                            end
                    end
            end
    end.

is_authorized(ReqData, Context) ->
    rabbit_mgmt_util:is_authorized_vhost(ReqData, Context).

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

%% Helper that formats a list into a message.
format_message(Message) when is_list(Message) ->
    maps:from_list(
        [{normalize_key(K), format_value(V)} || {K, V} <- Message]
    ).

%% normalize_key produces binary, which is needed for json.
normalize_key(K) when is_binary(K) ->
    K;
normalize_key(K) when is_atom(K) ->
    atom_to_binary(K, utf8);
normalize_key(K) ->
    iolist_to_binary(io_lib:format("~tp", [K])).

%% format_value is used only by format_message.
format_value(V) when is_binary(V) ->
    V;
format_value(V) when is_atom(V) ->
    atom_to_binary(V, utf8);
format_value(V) when is_list(V) ->
    [format_value(X) || X <- V];
format_value(V) ->
    V.
