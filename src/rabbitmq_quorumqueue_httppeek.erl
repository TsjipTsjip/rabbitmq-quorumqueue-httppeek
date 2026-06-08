%% This Source Code Form is subject to the terms of the Mozilla Public
%% License, v. 2.0. If a copy of the MPL was not distributed with this
%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%
%% Copyright (c) 2026 TsjipTsjip. All Rights Reserved.

-module(rabbitmq_quorumqueue_httppeek).

-behaviour(rabbit_mgmt_extension).

-export([dispatcher/0, web_ui/0]).

dispatcher() ->
    [{"/queues/:vhost/:queue/peek/:position", rabbit_mgmt_wm_queue_peek, []}].

web_ui() ->
    [].
